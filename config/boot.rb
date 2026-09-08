# frozen_string_literal: true

bundle_gemfile = File.expand_path("../Gemfile", __dir__)
bundle_lockfile = File.expand_path("../Gemfile.lock", __dir__)

# OCRAN intentionally neutralizes the build machine's Bundler environment for
# portable packages by exporting empty BUNDLE_GEMFILE/BUNDLE_LOCKFILE values
# and pointing BUNDLER_SETUP at a no-op file. Password Pusher still uses
# Bundler.require in config/application.rb, so restore the package-local
# Gemfile/lockfile and activate the bundled Bundler explicitly.
if ENV["PWP_STANDALONE"] == "1"
  ENV["BUNDLE_GEMFILE"] = bundle_gemfile
  ENV["BUNDLE_LOCKFILE"] = bundle_lockfile
  ENV.delete("BUNDLER_SETUP")

  gem "bundler", "4.0.12"
  require "bundler"
  Bundler.setup
else
  ENV["BUNDLE_GEMFILE"] ||= bundle_gemfile
  require "bundler/setup"
end

# Bootsnap caches absolute paths and provides little value for the portable
# standalone distribution, which already ships a fixed Ruby/gem tree.
unless ENV["DISABLE_BOOTSNAP"] == "1"
  require "bootsnap/setup" # Speed up boot time by caching expensive operations.
end
