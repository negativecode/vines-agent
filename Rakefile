require 'rake'
require 'rake/clean'
require 'rake/testtask'

CLOBBER.include('pkg')

directory 'pkg'

desc 'Build distributable packages'
task :build => [:pkg] do
  system 'gem build vines-agent.gemspec && mv vines-*.gem pkg/'
end

Rake::TestTask.new(:test) do |test|
  test.libs << 'test'
  test.pattern = 'test/**/*_test.rb'
  test.warning = false
end

task :default => [:clobber, :test, :build]
