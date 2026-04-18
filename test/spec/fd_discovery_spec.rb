# frozen_string_literal: true

require_relative "spec_helper"

RSpec.describe "fd repo discovery" do
  let(:result) { fd_repos }
  let(:paths)  { result.stdout.split("\n") }

  it "finds normal repos" do
    expect(paths).to include("/root/work/normal-repo")
  end

  it "finds repos with dots in the name" do
    expect(paths).to include("/root/work/dotted.repo")
  end

  it "finds nested repos within max-depth 4" do
    expect(paths).to include("/root/work/org/proj/nested-repo")
  end

  it "finds worktrees (mp-main)" do
    expect(paths).to include("/root/work/mp-main")
  end

  it "finds worktrees (mp-feature)" do
    expect(paths).to include("/root/work/mp-feature")
  end

  it "excludes bare repo directory from results" do
    bare_paths = paths.select { |p| p.include?("myproject.bare") }
    expect(bare_paths).to be_empty
  end

  it "excludes directories without .git" do
    expect(paths).not_to include("/root/work/not-a-repo")
  end

  it "excludes repos beyond max-depth 4" do
    deep = paths.select { |p| p.include?("too/deep") }
    expect(deep).to be_empty
  end

  it "strips .git suffix from all paths" do
    paths.each do |p|
      expect(p).not_to end_with("/.git")
      expect(p).not_to end_with("/.git/")
    end
  end
end
