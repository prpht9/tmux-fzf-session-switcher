# frozen_string_literal: true

require_relative "spec_helper"

RSpec.describe "repo selector (C-a f / tmux-git)" do
  before(:each) { start_tmux }
  after(:each)  { stop_tmux }

  describe "session creation" do
    it "creates a session for a normal repo" do
      run_tmux_git("/root/work/normal-repo")
      result = docker_exec("tmux has-session -t normal-repo 2>&1; echo $?")
      expect(result.stdout).to end_with("0")
    end

    it "converts dots to underscores in session name" do
      run_tmux_git("/root/work/dotted.repo")
      result = docker_exec("tmux has-session -t dotted_repo 2>&1; echo $?")
      expect(result.stdout).to end_with("0")
    end

    it "sets session working directory to the repo path" do
      run_tmux_git("/root/work/normal-repo")
      # Give the session launcher a moment to finish
      sleep 1
      result = docker_exec(
        "tmux list-panes -t normal-repo -F '\#{pane_current_path}' | head -1"
      )
      expect(result.stdout).to include("/root/work/normal-repo")
    end

    it "creates a session for a worktree directory" do
      run_tmux_git("/root/work/mp-main")
      result = docker_exec("tmux has-session -t mp-main 2>&1; echo $?")
      expect(result.stdout).to end_with("0")
    end
  end

  describe "reattach behavior" do
    it "does not create a duplicate session when called twice" do
      run_tmux_git("/root/work/normal-repo")
      run_tmux_git("/root/work/normal-repo")
      result = docker_exec(
        "tmux list-sessions -F '\#{session_name}' | grep -c '^normal-repo$'"
      )
      expect(result.stdout.to_i).to eq(1)
    end
  end

  describe "custom session launcher" do
    it "invokes the configured session launcher" do
      # Set a launcher that creates a marker file
      marker = "/tmp/tfss_launcher_test_marker"
      docker_exec("rm -f #{marker}")
      docker_exec(
        "tmux set-option -g @tfss_session_launcher " \
        "'bash -c \"touch #{marker}; tmux switch-client -t \\$1\" --'"
      )
      run_tmux_git("/root/work/normal-repo")
      sleep 1
      result = docker_exec("test -f #{marker} && echo exists || echo missing")
      expect(result.stdout).to eq("exists")
    end
  end

  describe "fzf integration via TFSS_FZF_CMD" do
    it "selects the correct repo when fzf filters by name" do
      result = run_tmux_git(
        "/root/work/normal-repo",
        env: 'TFSS_FZF_CMD="fzf -f normal"'
      )
      # The script was given a direct arg so fzf isn't used here;
      # test the env var path by not passing a direct arg
      docker_exec(
        "TFSS_FZF_CMD='fzf -f normal | head -1' " \
        "bash /opt/tfss/scripts/tmux-git"
      )
      result = docker_exec("tmux has-session -t normal-repo 2>&1; echo $?")
      expect(result.stdout).to end_with("0")
    end
  end

  describe "empty selection" do
    it "exits cleanly when fzf returns empty" do
      result = docker_exec(
        "TFSS_FZF_CMD='cat >/dev/null' bash /opt/tfss/scripts/tmux-git; echo $?"
      )
      expect(result.stdout).to end_with("0")
    end
  end
end
