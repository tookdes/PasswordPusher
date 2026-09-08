# frozen_string_literal: true

# Keep application version reporting independent from the git-sourced `version`
# gem when running from a packaged standalone bundle. Use a distinct filename
# so `require "version"` in release tooling can still load the upstream gem.
class Version
  def self.current
    @current ||= File.read(File.expand_path("../VERSION", __dir__), encoding: "UTF-8").strip
  rescue Errno::ENOENT
    "unknown"
  end
end
