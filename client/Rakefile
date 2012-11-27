require "rake"
require "rspec"
require "rspec/core/rake_task"

desc "Run specs"
task "spec" => ["bundler:install", "test:spec"]

desc "Run specs using RCov"
task "spec:rcov" => ["bundler:install", "test:spec:rcov"]

namespace "bundler" do
  desc "Install gems"
  task "install" do
    sh("bundle install")
  end
end

namespace "test" do
  desc "Run all specs"
  RSpec::Core::RakeTask.new(:spec) do |t|
    t.rspec_opts = ["--format", "documentation", "--colour"]
  end

  desc "Run all specs with rcov"
  coverage_dir = File.expand_path(File.join(File.dirname(__FILE__), "coverage"))
  RSpec::Core::RakeTask.new("spec:rcov") do |t|
    t.rspec_opts = []
    t.rcov = true
    t.rcov_opts = %W{--exclude osx\/objc,gems\/,spec\/,features\/ -o "#{coverage_dir}"}
  end
end
