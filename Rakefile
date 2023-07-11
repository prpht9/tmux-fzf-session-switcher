# frozen_string_literal: false

desc 'Create Github Release'
task :release do
  version = `cat VERSION`.chomp
  puts `gh release create #{version} -F CHANGELOG.md`
end
