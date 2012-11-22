
$:.unshift File.expand_path("../lib", __FILE__)

require "caldecott-client/version"

spec = Gem::Specification.new do |s|
  s.name = "caldecott-client"
  s.version = Caldecott::Client::VERSION
  s.author = "VMware"
  s.email = "support@vmware.com"
  s.homepage = "http://vmware.com"
  s.description = s.summary = "Caldecott Client HTTP/Websocket Tunneling Library"

  s.platform = Gem::Platform::RUBY
  s.extra_rdoc_files = ["README.md", "LICENSE"]

  s.add_dependency "json", "~> 1.6.1"

  s.add_development_dependency "rake",      "~> 0.9.2"
  s.add_development_dependency "rcov",      "~> 0.9.10"
  s.add_development_dependency "rack-test", "~> 0.6.1"
  s.add_development_dependency "rspec",     "~> 2.11.0"
  s.add_development_dependency "webmock",   "~> 1.7.6"

  s.require_path = "lib"
  s.files = %w(LICENSE README.md) + Dir.glob("{lib}/**/*")
end
