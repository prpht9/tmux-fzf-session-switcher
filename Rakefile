# frozen_string_literal: false

desc 'Create Github Release'
task :release do
  version = `cat VERSION`.chomp
  puts `gh release create #{version} -F CHANGELOG.md`
end

namespace :test do
  image_name = 'tfss-test'
  container_name = 'tfss-test'

  desc 'Build the test Docker image'
  task :build do
    sh "docker build -t #{image_name} test/"
  end

  desc 'Start the test container (build first if needed)'
  task up: :build do
    # Stop any existing container
    sh "docker rm -f #{container_name} 2>/dev/null; true"
    sh "docker run -d --name #{container_name} -v #{Dir.pwd}:/opt/tfss #{image_name}"
  end

  desc 'Stop and remove the test container'
  task :down do
    sh "docker rm -f #{container_name} 2>/dev/null; true"
  end

  desc 'Run integration specs (requires container)'
  task :integration do
    sh 'bundle exec rspec test/spec/ --format documentation'
  end
end

desc 'Run all tests'
task test: ['test:integration']
