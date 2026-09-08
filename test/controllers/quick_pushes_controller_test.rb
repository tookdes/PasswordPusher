# frozen_string_literal: true

require "test_helper"

class QuickPushesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
  end

  test "creation requires a signed in user" do
    get new_quick_push_path
    assert_redirected_to new_user_session_path
  end

  test "creates a short custom code without making the creator retrieve the push" do
    sign_in @user

    assert_difference("Push.count", 1) do
      post quick_pushes_path, params: {
        quick: {
          payload: "correct horse battery staple",
          passphrase: "4821",
          code: "phone-1",
          expire_after_days: 1,
          expire_after_views: 1
        }
      }
    end

    assert_response :created
    push = Push.find_by!(url_token: "phone-1")
    assert_equal @user, push.user
    assert_equal 0, push.view_count
    assert_includes response.body, "/s/phone-1"
    assert_includes response.body, "4821"
  end

  test "wrong passphrase does not consume a view and a successful read burns a one-view push" do
    sign_in @user
    post quick_pushes_path, params: {
      quick: {
        payload: "temporary-secret",
        passphrase: "4821",
        code: "burn-test",
        expire_after_days: 1,
        expire_after_views: 1
      }
    }
    assert_response :created
    sign_out @user

    push = Push.find_by!(url_token: "burn-test")

    post quick_access_path(push.url_token), params: {passphrase: "0000"}
    assert_response :unprocessable_content
    push.reload
    assert_equal 0, push.view_count
    assert_not push.expired?

    post quick_access_path(push.url_token), params: {passphrase: "4821"}
    assert_response :see_other
    follow_redirect!
    assert_response :success
    assert_includes response.body, "temporary-secret"
    assert_equal "no-store, no-cache, max-age=0, must-revalidate", response.headers["Cache-Control"]

    push.reload
    assert push.expired?
    assert_nil push.payload
  end

  test "automatically generated code is six unambiguous characters" do
    sign_in @user
    post quick_pushes_path, params: {
      quick: {
        payload: "temporary-secret",
        passphrase: "4821",
        code: "",
        expire_after_days: 1,
        expire_after_views: 1
      }
    }

    assert_response :created
    push = Push.order(:created_at).last
    assert_match(/\A[23456789abcdefghjkmnpqrstuvwxyz]{6}\z/, push.url_token)
  end
end
