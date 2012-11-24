require 'rake'
require 'rake/clean'
require 'rake/testtask'
require 'rubygems/package_task'
require_relative 'lib/vines/agent/version'

spec = Gem::Specification.new do |s|
  s.name    = "vines-agent"
  s.version = Vines::Agent::VERSION

  s.summary     = "An XMPP bot that runs shell commands on remote machines."
  s.description = "Vines Agent executes shell commands sent by users after
authorizing them against an access control list, provided by the Vines Services
component. Manage a server as easily as chatting with a friend."

  s.authors      = ["David Graham"]
  s.email        = %w[david@negativecode.com]
  s.homepage     = "http://www.getvines.org"

  s.files        = FileList['[A-Z]*', '{bin,lib,conf}/**/*']
  s.test_files   = FileList["test/**/*"]
  s.executables  = %w[vines-agent]
  s.require_path = "lib"

  s.add_dependency "blather", "~> 0.8.1"
  s.add_dependency "ohai", "~> 6.14.0"
  s.add_dependency "session", "~> 3.1.0"
  s.add_dependency "slave", "~> 1.3.0"
  s.add_dependency "vines", ">= 0.4.0"

  s.add_development_dependency "minitest"
  s.add_development_dependency "rake"

  s.required_ruby_version = '>= 1.9.3'
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

desc 'Helper task to be called from other rakefiles'
task :agent => [:clobber, :gem]

# FIXME Remove from production
desc 'Runs an agent from command line'
task :run do
  Dir.chdir("/home/am/NetBeansProjects/Repos/wonderland.lit/agent") do
    sh "ruby -I/home/am/NetBeansProjects/vines-agent.git/lib /home/am/NetBeansProjects/vines-agent.git/bin/vines-agent start"
  end
end
