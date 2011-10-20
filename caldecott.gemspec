
$:.unshift File.expand_path("../lib", __FILE__)

require 'caldecott/version'

spec = Gem::Specification.new do |s|
  s.name = "caldecott"
  s.version = Caldecott::VERSION
  s.author = "VMware"
  s.email = "support@vmware.com"
  s.homepage = "http://vmware.com"
  s.description = s.summary = "TBD"

  s.platform = Gem::Platform::RUBY
  s.extra_rdoc_files = ["README.md", "LICENSE"]

  s.require_path = 'lib'
  s.files = %w(LICENSE README.md) + Dir.glob("{lib}/**/*")
end
