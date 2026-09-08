# frozen_string_literal: true

# Keep application version reporting independent from the git-sourced `version`
# gem when running from a packaged bundle. This file lives under config rather
# than lib so Rails/Zeitwerk does not infer a constant name from its filename.
class Version
  def self.current
    @current ||= File.read(File.expand_path("../VERSION", __dir__), encoding: "UTF-8").strip
  rescue Errno::ENOENT
    "unknown"
  end
end
