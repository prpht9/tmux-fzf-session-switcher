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
    docker_exec("rm -rf /root/work/my-inline-wt")
    docker_exec("git -C /root/work/myproject.bare config --unset tfss.prefix 2>/dev/null; true")
    docker_exec("git -C /root/work/myproject.bare worktree prune 2>/dev/null; true")
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
    it "creates a bare repo and first worktree without prefix" do
      script = <<~EXPECT
        set timeout 15
        spawn bash /opt/tfss/scripts/tmux-git-new-repo
        expect "New Repo*"
        send "b"
        expect "Bare Repo URL*"
        send "/root/work/normal-repo\\r"
        expect "New Bare Repo Location*"
        send "work/bareclone.bare\\r"
        expect "prefix*"
        send "\\r"
        expect "New worktree*"
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

    it "creates a bare repo with prefix and auto-prepends to worktree name" do
      docker_exec("rm -rf /root/work/prefclone.bare /root/work/pf-main")
      script = <<~EXPECT
        set timeout 15
        spawn bash /opt/tfss/scripts/tmux-git-new-repo
        expect "New Repo*"
        send "b"
        expect "Bare Repo URL*"
        send "/root/work/normal-repo\\r"
        expect "New Bare Repo Location*"
        send "work/prefclone.bare\\r"
        expect "prefix*"
        send "pf\\r"
        expect "*pf-*"
        send "main\\r"
        expect eof
      EXPECT
      run_wizard_with_expect(script)
      sleep 1

      # Prefix stored in git config
      result = docker_exec("git -C /root/work/prefclone.bare config tfss.prefix")
      expect(result.stdout).to eq("pf")

      # Worktree created with prefix
      result = docker_exec("test -f /root/work/pf-main/.git && echo yes || echo no")
      expect(result.stdout).to eq("yes")

      result = docker_exec("tmux has-session -t pf-main 2>&1; echo $?")
      expect(result.stdout).to end_with("0")
    end
  end

  describe "worktree from bare flow (w)" do
    it "adds a worktree to an existing bare repo without prefix" do
      # myproject.bare has no prefix — skips prefix prompt, shows plain worktree prompt
      script = <<~EXPECT
        set timeout 15
        set env(TFSS_FZF_CMD) "grep myproject"
        spawn bash /opt/tfss/scripts/tmux-git-new-repo
        expect "New Repo*"
        send "w"
        expect "Set prefix*"
        send "\\r"
        expect "New worktree*"
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

    it "prompts to set prefix when missing and uses it for worktree name" do
      docker_exec("rm -rf /root/work/my-inline-wt")
      docker_exec("git -C /root/work/myproject.bare worktree prune 2>/dev/null; true")
      docker_exec("git -C /root/work/myproject.bare config --unset tfss.prefix 2>/dev/null; true")
      script = <<~EXPECT
        set timeout 15
        set env(TFSS_FZF_CMD) "grep myproject"
        spawn bash /opt/tfss/scripts/tmux-git-new-repo
        expect "New Repo*"
        send "w"
        expect "Set prefix*"
        send "my\\r"
        expect "*/root/work/my-*"
        send "inline-wt\\r"
        expect eof
      EXPECT
      run_wizard_with_expect(script)
      sleep 1

      result = docker_exec("git -C /root/work/myproject.bare config tfss.prefix")
      expect(result.stdout).to eq("my")

      result = docker_exec("test -d /root/work/my-inline-wt && echo yes || echo no")
      expect(result.stdout).to eq("yes")
    end
  end

  describe "worktree with prefix (w)" do
    before(:each) do
      docker_exec("rm -rf /root/work/px-new-wt /root/work/px-override-wt")
      docker_exec("git -C /root/work/prefixed.bare worktree prune 2>/dev/null; true")
    end

    it "auto-prepends prefix to worktree name" do
      # prefixed.bare has tfss.prefix = px
      script = <<~EXPECT
        set timeout 15
        set env(TFSS_FZF_CMD) "grep prefixed"
        spawn bash /opt/tfss/scripts/tmux-git-new-repo
        expect "New Repo*"
        send "w"
        expect "*px-*"
        send "new-wt\\r"
        expect eof
      EXPECT
      run_wizard_with_expect(script)
      sleep 1

      result = docker_exec("test -d /root/work/px-new-wt && echo yes || echo no")
      expect(result.stdout).to eq("yes")

      result = docker_exec("tmux has-session -t px-new-wt 2>&1; echo $?")
      expect(result.stdout).to end_with("0")
    end

    it "pre-fills path and prefix in the prompt" do
      # With read -e -i, the prompt shows "/root/work/px-" pre-filled
      # Sending just the suffix appends to it
      script = <<~EXPECT
        set timeout 15
        set env(TFSS_FZF_CMD) "grep prefixed"
        spawn bash /opt/tfss/scripts/tmux-git-new-repo
        expect "New Repo*"
        send "w"
        expect "*/root/work/px-*"
        send "override-wt\\r"
        expect eof
      EXPECT
      run_wizard_with_expect(script)
      sleep 1

      result = docker_exec("test -d /root/work/px-override-wt && echo yes || echo no")
      expect(result.stdout).to eq("yes")
    end
  end

  describe "set prefix flow (p)" do
    it "sets prefix on an existing bare repo" do
      docker_exec("git -C /root/work/myproject.bare config --unset tfss.prefix 2>/dev/null; true")
      script = <<~EXPECT
        set timeout 15
        set env(TFSS_FZF_CMD) "grep myproject"
        spawn bash /opt/tfss/scripts/tmux-git-new-repo
        expect "New Repo*"
        send "p"
        expect "Enter prefix*"
        send "mp\\r"
        expect "Prefix set*"
        expect eof
      EXPECT
      result = run_wizard_with_expect(script)
      expect(result.stdout).to include("Prefix set")

      result = docker_exec("git -C /root/work/myproject.bare config tfss.prefix")
      expect(result.stdout).to eq("mp")
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
