# frozen_string_literal: true

ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../Gemfile", __dir__)

# OCRAN already packages the resolved gems and exposes them through RubyGems.
# Loading Bundler again inside the self-extracting executable can try to activate
# the host Ruby's default Bundler version instead of the bundled one.
unless ENV["PWP_STANDALONE"] == "1"
  require "bundler/setup" # Set up gems listed in the Gemfile.
end

# Bootsnap caches absolute paths and provides little value for a self-extracting
# executable whose application directory changes on every run.
unless ENV["DISABLE_BOOTSNAP"] == "1"
  require "bootsnap/setup" # Speed up boot time by caching expensive operations.
end
