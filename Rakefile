require 'rake'
require 'rake/clean'
require 'rake/testtask'
require 'rubygems/package_task'
require_relative 'lib/vines/agent/version'

spec = Gem::Specification.new do |s|
  s.name    = "vines-agent"
  s.version = Vines::Agent::VERSION
  s.date    = Time.now.strftime("%Y-%m-%d")

  s.summary     = "An XMPP bot that runs shell commands on remote machines."
  s.description = "Vines Agent executes shell commands sent by users after
authorizing them against an access control list, provided by the Vines Services
component. Manage a server as easily as chatting with a friend."

  s.authors      = ["David Graham", "Chris Johnson"]
  s.email        = %w[david@negativecode.com chris@negativecode.com]
  s.homepage     = "http://www.getvines.com"

  s.files        = FileList['[A-Z]*', '{bin,lib,conf}/**/*']
  s.test_files   = FileList["test/**/*"]
  s.executables  = %w[vines-agent]
  s.require_path = "lib"

  s.add_dependency "blather", "~> 0.5.4"
  s.add_dependency "ohai", "~> 0.6.4"
  s.add_dependency "session", "~> 3.1.0"
  s.add_dependency "slave", "~> 1.2.1"
  s.add_dependency "vines", "~> 0.3"

  s.add_development_dependency "minitest"
  s.add_development_dependency "rake"

  s.required_ruby_version = '>= 1.9.2'
end

Gem::PackageTask.new(spec) do |pkg|
  pkg.need_tar = true
end

module Rake
  class TestTask
    # use our custom test loader
    def rake_loader
      'test/rake_test_loader.rb'
    end
  end
end

Rake::TestTask.new(:test) do |test|
  test.libs << 'test'
  test.libs << 'test/storage'
  test.pattern = 'test/**/*_test.rb'
  test.warning = false
end

task :default => [:clobber, :test, :gem]
