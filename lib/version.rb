# frozen_string_literal: true

# Keep version reporting independent from the git-sourced `version` gem when
# running from a packaged standalone bundle. The upstream gem defines Version
# as a class, so keep the same constant shape for compatibility with tooling
# that may explicitly load the gem outside the portable package.
class Version
  def self.current
    @current ||= File.read(File.expand_path("../VERSION", __dir__), encoding: "UTF-8").strip
  rescue Errno::ENOENT
    "unknown"
  end
end
