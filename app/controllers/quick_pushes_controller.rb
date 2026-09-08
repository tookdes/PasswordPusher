# frozen_string_literal: true

require "securerandom"

class QuickPushesController < ApplicationController
  include LogEvents

  SHORT_CODE_ALPHABET = "23456789abcdefghjkmnpqrstuvwxyz".freeze
  SHORT_CODE_LENGTH = 6
  STORAGE_TOKEN_PREFIX = "q."
  CUSTOM_CODE_PATTERN = /\A[a-z0-9](?:[a-z0-9-]{1,22}[a-z0-9])\z/

  before_action :authenticate_user!, only: %i[new create]
  before_action :set_push, only: %i[show passphrase access]
  after_action :set_secret_response_headers, only: %i[new create show passphrase access]

  rate_limit to: 5, within: 1.minute, only: :access,
    by: -> { params[:id] },
    scope: :quick_passphrase_attempts,
    name: "quick-passphrase-per-push",
    with: -> { redirect_to quick_passphrase_path(params[:id], limited: 1) }

  def new
    @quick = default_form_values
  end

  def create
    @quick = quick_params.to_h.symbolize_keys
    @quick[:payload] = @quick[:payload].to_s
    @quick[:passphrase] = @quick[:passphrase].to_s
    @quick[:code] = @quick[:code].to_s.strip.downcase

    errors = validate_quick_params(@quick)
    unless errors.empty?
      @errors = errors
      render :new, status: :unprocessable_content
      return
    end

    @push = Push.new(
      kind: :text,
      payload: @quick[:payload],
      passphrase: @quick[:passphrase],
      expire_after_days: @quick[:expire_after_days].to_i,
      expire_after_views: @quick[:expire_after_views].to_i,
      retrieval_step: false,
      deletable_by_viewer: false,
      user_id: current_user.id
    )

    Push.transaction do
      @push.save!
      assign_short_code!(@push, @quick[:code])
      log_creation(@push)
    end

    short_code = short_code_for(@push)
    @share_url = quick_push_url(short_code)
    @share_code = short_code
    @share_passphrase = @quick[:passphrase]
    render :created, status: :created
  rescue ActiveRecord::RecordInvalid => e
    @errors = e.record.errors.full_messages
    render :new, status: :unprocessable_content
  rescue ActiveRecord::RecordNotUnique
    @errors = ["取件地址已被占用，请换一个。"]
    render :new, status: :unprocessable_content
  end

  def passphrase
    @push.check_limits
    if @push.expired?
      render :expired, layout: false, status: :gone
      return
    end

    @error = params[:limited].present? ? "尝试次数过多，请稍后再试。" : nil
    render :passphrase, layout: false
  end

  def access
    @push.check_limits
    if @push.expired?
      render :expired, layout: false, status: :gone
      return
    end

    supplied = params[:passphrase].to_s
    if ActiveSupport::SecurityUtils.secure_compare(@push.passphrase.to_s, supplied)
      cookies[quick_cookie_name] = {
        value: @push.passphrase_ciphertext,
        expires: 3.minutes.from_now,
        secure: Settings.secure_cookies,
        httponly: true,
        same_site: :lax
      }
      redirect_to quick_push_path(short_code_for(@push)), status: :see_other
    else
      log_failed_passphrase(@push)
      @error = "取件码错误。"
      render :passphrase, layout: false, status: :unprocessable_content
    end
  end

  def show
    @push.check_limits
    if @push.expired?
      render :expired, layout: false, status: :gone
      return
    end

    if @push.passphrase.present?
      authenticated = ActiveSupport::SecurityUtils.secure_compare(
        @push.passphrase_ciphertext.to_s,
        cookies[quick_cookie_name].to_s
      )
      unless authenticated
        redirect_to quick_passphrase_path(short_code_for(@push))
        return
      end
      cookies.delete(quick_cookie_name)
    end

    result = @push.claim_view!(
      viewer: user_signed_in? ? current_user : nil,
      admin: user_signed_in? && current_user.admin?,
      ip: request.remote_ip,
      user_agent: request.env["HTTP_USER_AGENT"],
      referrer: request.env["HTTP_REFERER"]
    )

    if result.expired?
      render :expired, layout: false, status: :gone
      return
    end

    @payload = result.payload
    render :show, layout: false
    @push.expire! if result.expire_after_response
  end

  private

  def quick_params
    params.require(:quick).permit(:payload, :passphrase, :code, :expire_after_days, :expire_after_views)
  end

  def default_form_values
    {
      payload: "",
      passphrase: "",
      code: "",
      expire_after_days: [1, Settings.pw.expire_after_days_min].max,
      expire_after_views: 1
    }
  end

  def validate_quick_params(values)
    errors = []
    errors << "内容不能为空。" if values[:payload].blank?
    errors << "取件码至少需要 4 个字符。" if values[:passphrase].length < 4

    code = values[:code]
    if code.present? && !CUSTOM_CODE_PATTERN.match?(code)
      errors << "自定义地址只能使用 3–24 位小写字母、数字和连字符，且不能以连字符开头或结尾。"
    end
    errors << "该自定义地址已被占用。" if code.present? && Push.exists?(url_token: storage_token(code))

    days = values[:expire_after_days].to_i
    unless days.between?(Settings.pw.expire_after_days_min, Settings.pw.expire_after_days_max)
      errors << "有效期超出服务器允许范围。"
    end

    views = values[:expire_after_views].to_i
    unless views.between?(Settings.pw.expire_after_views_min, Settings.pw.expire_after_views_max)
      errors << "读取次数超出服务器允许范围。"
    end

    errors
  end

  def assign_short_code!(push, requested_code)
    if requested_code.present?
      token = storage_token(requested_code)
      push.update_column(:url_token, token)
      push.url_token = token
      return
    end

    20.times do
      code = Array.new(SHORT_CODE_LENGTH) {
        SHORT_CODE_ALPHABET[SecureRandom.random_number(SHORT_CODE_ALPHABET.length)]
      }.join
      token = storage_token(code)
      next if Push.exists?(url_token: token)

      begin
        push.update_column(:url_token, token)
        push.url_token = token
        return
      rescue ActiveRecord::RecordNotUnique
        next
      end
    end

    raise ActiveRecord::RecordNotUnique, "could not allocate a unique short code"
  end

  def set_push
    code = params[:id].to_s.downcase
    raise ActiveRecord::RecordNotFound unless CUSTOM_CODE_PATTERN.match?(code)

    @push = Push.includes(:audit_logs).find_by!(url_token: storage_token(code), kind: :text)
    @short_code = code
  rescue ActiveRecord::RecordNotFound
    render :expired, layout: false, status: :gone
  end

  def storage_token(code)
    "#{STORAGE_TOKEN_PREFIX}#{code}"
  end

  def short_code_for(push)
    push.url_token.delete_prefix(STORAGE_TOKEN_PREFIX)
  end

  def quick_cookie_name
    "quick-#{short_code_for(@push)}-p"
  end

  def set_secret_response_headers
    response.headers["Cache-Control"] = "no-store, no-cache, max-age=0, must-revalidate"
    response.headers["Pragma"] = "no-cache"
    response.headers["Referrer-Policy"] = "no-referrer"
    response.headers["X-Robots-Tag"] = "noindex, nofollow, noarchive"
  end
end
