# frozen_string_literal: true

ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../Gemfile", __dir__)

# Rails' application boot still relies on Bundler.require to load third-party
# integrations such as Devise and Lockbox. The binary workflow aligns the
# packaged Bundler version with Ruby's default Bundler before OCRAN runs.
require "bundler/setup"

# Bootsnap caches absolute paths and provides little value for a self-extracting
# executable whose application directory changes on every run.
unless ENV["DISABLE_BOOTSNAP"] == "1"
  require "bootsnap/setup" # Speed up boot time by caching expensive operations.
end
