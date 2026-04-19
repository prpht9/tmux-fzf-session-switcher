# frozen_string_literal: true

require_relative "spec_helper"

RSpec.describe "new repo wizard (C-a n / tmux-git-new-repo)" do
  before(:each) do
    start_tmux
    # Clean up any test artifacts from previous runs
    docker_exec("rm -rf /root/work/testrepo")
    docker_exec("rm -rf /root/work/clonetest")
    docker_exec("rm -rf /root/work/bareclone.bare")
    docker_exec("rm -rf /root/work/bc-main")
    docker_exec("rm -rf /root/work/new-worktree")
  end

  after(:each) { stop_tmux }

  # Use expect(1) to script interactive input to the wizard.
  # expect sends keystrokes and waits for prompts.
  def run_wizard_with_expect(expect_script, timeout: 15)
    docker_exec(
      "expect -c '#{expect_script.gsub("'", "'\\\\''")}'",
      timeout: timeout
    )
  end

  describe "new repo flow (n)" do
    it "creates a git repo and tmux session" do
      script = <<~EXPECT
        set timeout 10
        spawn bash /opt/tfss/scripts/tmux-git-new-repo
        expect "New Repo*"
        send "n"
        expect "New Repo Location*"
        send "testrepo\\r"
        expect eof
      EXPECT
      run_wizard_with_expect(script)
      sleep 1

      # Verify the directory and .git exist
      result = docker_exec("test -d /root/work/testrepo/.git && echo yes || echo no")
      expect(result.stdout).to eq("yes")

      # Verify tmux session was created
      result = docker_exec("tmux has-session -t testrepo 2>&1; echo $?")
      expect(result.stdout).to end_with("0")
    end

    it "exits with error when repo location is empty" do
      script = <<~EXPECT
        set timeout 10
        spawn bash /opt/tfss/scripts/tmux-git-new-repo
        expect "New Repo*"
        send "n"
        expect "New Repo Location*"
        send "\\r"
        expect eof
        catch wait result
        exit [lindex $result 3]
      EXPECT
      result = run_wizard_with_expect(script)
      expect(result.stdout).to include("Must Enter")
    end
  end

  describe "normal clone flow (c)" do
    it "clones a repo and creates a session" do
      # Use the bare fixture as a local "remote"
      script = <<~EXPECT
        set timeout 15
        spawn bash /opt/tfss/scripts/tmux-git-new-repo
        expect "New Repo*"
        send "c"
        expect "Clone Repo URL*"
        send "/root/work/normal-repo\\r"
        expect "New Repo Location*"
        send "work/clonetest\\r"
        expect eof
      EXPECT
      run_wizard_with_expect(script)
      sleep 1

      result = docker_exec("test -d /root/work/clonetest/.git && echo yes || echo no")
      expect(result.stdout).to eq("yes")

      result = docker_exec("tmux has-session -t clonetest 2>&1; echo $?")
      expect(result.stdout).to end_with("0")
    end
  end

  describe "bare clone flow (b)" do
    it "creates a bare repo and first worktree" do
      script = <<~EXPECT
        set timeout 15
        spawn bash /opt/tfss/scripts/tmux-git-new-repo
        expect "New Repo*"
        send "b"
        expect "Bare Repo URL*"
        send "/root/work/normal-repo\\r"
        expect "New Bare Repo Location*"
        send "work/bareclone.bare\\r"
        expect "New Worktree Name*"
        send "bc-main\\r"
        expect eof
      EXPECT
      run_wizard_with_expect(script)
      sleep 1

      # Bare repo directory exists
      result = docker_exec("test -d /root/work/bareclone.bare && echo yes || echo no")
      expect(result.stdout).to eq("yes")

      # Worktree directory exists with .git file (not directory)
      result = docker_exec("test -f /root/work/bc-main/.git && echo yes || echo no")
      expect(result.stdout).to eq("yes")

      # Session created for the worktree, not the bare repo
      result = docker_exec("tmux has-session -t bc-main 2>&1; echo $?")
      expect(result.stdout).to end_with("0")
    end
  end

  describe "worktree from bare flow (w)" do
    it "adds a worktree to an existing bare repo" do
      # Use the fixture's myproject.bare
      script = <<~EXPECT
        set timeout 15
        set env(TFSS_FZF_CMD) "head -1"
        spawn bash /opt/tfss/scripts/tmux-git-new-repo
        expect "New Repo*"
        send "w"
        expect "worktree*"
        send "new-worktree\\r"
        expect eof
      EXPECT
      run_wizard_with_expect(script)
      sleep 1

      result = docker_exec("test -d /root/work/new-worktree && echo yes || echo no")
      expect(result.stdout).to eq("yes")

      result = docker_exec("tmux has-session -t new-worktree 2>&1; echo $?")
      expect(result.stdout).to end_with("0")
    end
  end

  describe "empty choice" do
    it "exits cleanly when user presses Enter at flow choice" do
      script = <<~EXPECT
        set timeout 5
        spawn bash /opt/tfss/scripts/tmux-git-new-repo
        expect "New Repo*"
        send "\\r"
        expect eof
        catch wait result
        exit [lindex $result 3]
      EXPECT
      result = run_wizard_with_expect(script)
      expect(result.exit_code).to eq(0)
    end
  end

  describe "invalid choice" do
    it "shows error for invalid input" do
      script = <<~EXPECT
        set timeout 5
        spawn bash /opt/tfss/scripts/tmux-git-new-repo
        expect "New Repo*"
        send "x"
        expect eof
      EXPECT
      result = run_wizard_with_expect(script)
      expect(result.stdout).to include("Repo Command Invalid")
    end
  end
end
