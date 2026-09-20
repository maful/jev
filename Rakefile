# frozen_string_literal: true

require "bundler/gem_tasks"
require "minitest/test_task"

Minitest::TestTask.create

require "rubocop/rake_task"

RuboCop::RakeTask.new

desc "Validate RBS declarations"
task :rbs do
  sh "rbs -I sig validate"
end

task default: %i[test rbs rubocop]
