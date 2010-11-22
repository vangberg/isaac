task :default => :test

require 'rake/testtask'
require 'rake/clean'
require 'rubygems'

desc "Run test suite."
Rake::TestTask.new do |t|
  t.libs << "test" << "lib"
  t.test_files = FileList['test/test_*.rb']
  t.verbose = true
end

desc "Build a standard gem"
task :build_gem => :clean do
   spec = eval(IO.read('isaac.gemspec'))
   Gem::Builder.new(spec).build
end

CLEAN.include("*.gem")
