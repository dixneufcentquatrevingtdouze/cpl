#!/usr/bin/env ruby
# frozen_string_literal: true

require 'rake'
require 'rake/testtask'

task default: :test

desc 'Run test suite'
Rake::TestTask.new(:test) do |t|
  t.libs << 'test'
  t.pattern = 'test/**/*_test.rb'
  t.warning = true
end

desc 'Generate playlist from MP4 files'
task :playlist, [:directory] do |_, args|
  dir = args[:directory] || abort('Usage: rake playlist[<directory>]')
  ruby '-Ilib', 'mkpl.rb', dir
end

desc 'Run the script directly'
task :run, [:directory] do |_, args|
  dir = args[:directory] || abort('Usage: rake run[<directory>]')
  ruby 'mkpl.rb', dir
end

desc 'Show available tasks'
task :tasks do
  puts 'Available tasks:'
  Rake::Task.tasks.select { |t| t.comment }.each do |t|
    puts "  #{t.name.ljust(30)} — #{t.comment}"
  end
end
