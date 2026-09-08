# frozen_string_literal: true

# Add your own tasks in files placed in lib/tasks ending in .rake,
# for example lib/tasks/capistrano.rake, and they will automatically be available to Rake.

require File.expand_path("config/application", __dir__)

PasswordPusher::Application.load_tasks

# The application itself uses lib/version.rb so packaged runtime startup does
# not depend on the git-sourced gem. Explicitly load the upstream gem here only
# for its release/version Rake extensions and tasks.
require "version"
require "rake/version_task"
Rake::VersionTask.new do |task|
  task.with_git_tag = true
  task.git_tag_prefix = "v"
end
