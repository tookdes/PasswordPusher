# frozen_string_literal: true

# Keep version reporting independent from the git-sourced `version` gem when
# running from a packaged standalone bundle.  The upstream application only
# needs Version.current here, and VERSION is already shipped with every build.
module Version
  module_function

  def current
    @current ||= File.read(File.expand_path("../VERSION", __dir__), encoding: "UTF-8").strip
  rescue Errno::ENOENT
    "unknown"
  end
end
