desc "Create Github Release"
task :release do
  version = `cat VERSION`
  puts `gh release create #{version} -F CHANGELOG.md`
end
