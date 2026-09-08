# frozen_string_literal: true

ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../Gemfile", __dir__)

# Ruby 4.0.6 ships Bundler 4.0.16 as a default gem, while this application's
# lockfile is generated with Bundler 4.0.12. OCRAN packages the lockfile Bundler,
# so activate that exact version before requiring bundler/setup. Normal source
# and Docker deployments keep their usual Bundler activation behavior.
gem "bundler", "4.0.12" if ENV["PWP_STANDALONE"] == "1"
require "bundler/setup"

# Bootsnap caches absolute paths and provides little value for a self-extracting
# executable whose application directory changes on every run.
unless ENV["DISABLE_BOOTSNAP"] == "1"
  require "bootsnap/setup" # Speed up boot time by caching expensive operations.
end
