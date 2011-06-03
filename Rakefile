require "bundler"
Bundler.setup :default

task :default => :test

require "rake/testtask"
Rake::TestTask.new :test do |t|
  t.test_files = FileList["test/*_test.rb"]
end

Bundler::GemHelper.install_tasks
