# encoding: utf-8

require 'rubygems'
require 'bundler'
begin
  Bundler.setup(:default, :development)
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts "Run `bundle install` to install missing gems"
  exit e.status_code
end
require 'rake'

require 'jeweler'
Jeweler::Tasks.new do |gem|
  # gem is a Gem::Specification... see http://docs.rubygems.org/read/chapter/20 for more options
  gem.name = "q3"
  gem.homepage = "http://github.com/tily/q3"
  gem.license = "MIT"
  gem.summary = %Q{Simple Amazon SQS compatible API implementation with sinatra and redis}
  gem.description = %Q{Simple Amazon SQS compatible API implementation with sinatra and redis}
  gem.email = "tily05@gmail.com"
  gem.authors = ["tily"]
  # dependencies defined in Gemfile
  gem.executables = ['q3']
end
Jeweler::RubygemsDotOrgTasks.new

require 'rspec/core'
require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new(:spec) do |spec|
  spec.pattern = FileList['spec/**/*_spec.rb']
end

RSpec::Core::RakeTask.new(:rcov) do |spec|
  spec.pattern = 'spec/**/*_spec.rb'
  spec.rcov = true
end

task :default => :spec
