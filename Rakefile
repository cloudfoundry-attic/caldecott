require 'rake'

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
  task "spec" do |t|
    sh("cd spec && rake spec")
  end

  task "spec:rcov" do |t|
    sh("cd spec && rake spec:rcov")
  end
end
