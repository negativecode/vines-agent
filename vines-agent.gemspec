require './lib/vines/agent/version'

Gem::Specification.new do |s|
  s.name    = 'vines-agent'
  s.version = Vines::Agent::VERSION

  s.summary     = %q[An XMPP bot that runs shell commands on remote machines.]
  s.description = %q[Execute shell commands, authorizing them against a vines-services access control list.]

  s.authors      = ['David Graham']
  s.email        = %w[david@negativecode.com]
  s.homepage     = 'http://www.getvines.org'
  s.license      = 'MIT'

  s.files        = Dir['[A-Z]*', 'vines-agent.gemspec', '{bin,lib,conf}/**/*'] - ['Gemfile.lock']
  s.test_files   = Dir['test/**/*']

  s.executables  = %w[vines-agent]
  s.require_path = 'lib'

  s.add_dependency 'blather', '~> 0.8.5'
  s.add_dependency 'ohai', '~> 0.6.10'
  s.add_dependency 'session', '~> 3.1.0'
  s.add_dependency 'slave', '~> 1.3.0'
  s.add_dependency 'vines', '>= 0.4.6'

  s.add_development_dependency 'minitest', '~> 5.0.5'
  s.add_development_dependency 'rake', '~> 10.1.0'

  s.required_ruby_version = '>= 1.9.3'
end
