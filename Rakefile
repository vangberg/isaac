task :default => :test

require 'rake/testtask'

Rake::TestTask.new do |t|
  t.libs << "test" << "lib"
  t.test_files = FileList['test/test_*.rb']
  t.verbose = true
end
