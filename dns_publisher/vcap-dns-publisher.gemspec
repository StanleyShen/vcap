
$:.unshift File.expand_path("../lib", __FILE__)

require 'vcap_dns_publisher/version'

spec = Gem::Specification.new do |s|
  s.name = "vcap_dns_publisher"
  s.version = "0.0.01"
  s.author = "Intalio Pte"
  s.email = "hmalphettes@gmail.com"
  s.homepage = "http://intalio.com"
  s.description = s.summary = "Listens to apps stopping and starting on Cloudfoundry. Publishes the hostnames on multicast-DNS or route53; support for plugins. Must be run next to the vcap router for mDNS"
  s.executables = %w(vcap-mdns-publisher)

  s.platform = Gem::Platform::RUBY
  s.extra_rdoc_files = ["README.md", "LICENSE"]

  s.add_dependency "nats"
#  s.add_dependency "route53"
  #s.add_development_dependency "rake"
#  s.add_development_dependency "rspec",   "~> 1.3.0"
#  s.add_development_dependency "webmock", "= 1.5.0"

  s.bindir  = "bin"
  s.require_path = 'lib'
  s.files = %w(LICENSE README.md) + Dir.glob("{lib}/**/*")
end
