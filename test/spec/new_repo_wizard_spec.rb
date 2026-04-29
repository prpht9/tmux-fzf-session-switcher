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

  describe "jira worktree flow (j)" do
    before(:each) do
      # worktree remove before rm -rf so git housekeeping stays clean
      docker_exec("git -C /root/work/prefixed.bare worktree remove --force /root/work/px/feat-PROJ-42 2>/dev/null; true")
      docker_exec("git -C /root/work/prefixed.bare worktree remove --force /root/work/px/task-MP-99 2>/dev/null; true")
      docker_exec("git -C /root/work/myproject.bare worktree remove --force /root/work/mp/feat-MP-1 2>/dev/null; true")
      docker_exec("rm -rf /root/work/px")   # jira subdir for prefixed.bare (distinct from px-main sibling)
      docker_exec("rm -rf /root/work/mp")   # jira subdir for myproject.bare when prefix = mp
      docker_exec("git -C /root/work/prefixed.bare worktree prune 2>/dev/null; true")
      # outer before(:each) already unsets myproject.bare prefix and prunes it
    end

    it "shows 'Jira Worktree (j)' in the menu" do
      script = <<~EXPECT
        set timeout 5
        spawn bash /opt/tfss/scripts/tmux-git-new-repo
        expect "New Repo*"
        send "\\r"
        expect eof
      EXPECT
      result = run_wizard_with_expect(script)
      expect(result.stdout).to include("Jira Worktree (j)")
    end

    it "creates the worktree at {parent}/{prefix}/{name}-{jira_id}, not as a flat sibling" do
      # prefixed.bare is at /root/work/prefixed.bare → parent = /root/work, prefix = px
      # so the jira worktree must land at /root/work/px/feat-PROJ-42
      script = <<~EXPECT
        set timeout 15
        set env(TFSS_FZF_CMD) "grep prefixed"
        spawn bash /opt/tfss/scripts/tmux-git-new-repo
        expect "New Repo*"
        send "j"
        expect "Worktree name*"
        send "feat\\r"
        expect "Jira ID*"
        send "PROJ-42\\r"
        expect eof
      EXPECT
      run_wizard_with_expect(script)
      sleep 1

      # Correct nested location
      result = docker_exec("test -f /root/work/px/feat-PROJ-42/.git && echo yes || echo no")
      expect(result.stdout).to eq("yes")

      # Must NOT appear at the flat-sibling location regular worktrees use
      result = docker_exec("test -d /root/work/px-feat-PROJ-42 && echo yes || echo no")
      expect(result.stdout).to eq("no")
    end

    it "creates a tmux session named after the worktree directory basename" do
      script = <<~EXPECT
        set timeout 15
        set env(TFSS_FZF_CMD) "grep prefixed"
        spawn bash /opt/tfss/scripts/tmux-git-new-repo
        expect "New Repo*"
        send "j"
        expect "Worktree name*"
        send "feat\\r"
        expect "Jira ID*"
        send "PROJ-42\\r"
        expect eof
      EXPECT
      run_wizard_with_expect(script)
      sleep 1

      result = docker_exec("tmux has-session -t feat-PROJ-42 2>&1; echo $?")
      expect(result.stdout).to end_with("0")
    end

    it "creates the {prefix}/ grouping directory when it does not yet exist" do
      pre = docker_exec("test -d /root/work/px && echo yes || echo no")
      expect(pre.stdout).to eq("no") # pre-condition: dir absent before the run

      script = <<~EXPECT
        set timeout 15
        set env(TFSS_FZF_CMD) "grep prefixed"
        spawn bash /opt/tfss/scripts/tmux-git-new-repo
        expect "New Repo*"
        send "j"
        expect "Worktree name*"
        send "feat\\r"
        expect "Jira ID*"
        send "PROJ-42\\r"
        expect eof
      EXPECT
      run_wizard_with_expect(script)
      sleep 1

      result = docker_exec("test -d /root/work/px && echo yes || echo no")
      expect(result.stdout).to eq("yes")
    end

    it "prompts to set prefix when missing, saves it, then creates at {parent}/{prefix}/{name}-{jira_id}" do
      # myproject.bare has no prefix — cleared by outer before(:each)
      script = <<~EXPECT
        set timeout 15
        set env(TFSS_FZF_CMD) "grep myproject"
        spawn bash /opt/tfss/scripts/tmux-git-new-repo
        expect "New Repo*"
        send "j"
        expect "Set prefix*"
        send "mp\\r"
        expect "Worktree name*"
        send "feat\\r"
        expect "Jira ID*"
        send "MP-1\\r"
        expect eof
      EXPECT
      run_wizard_with_expect(script)
      sleep 1

      # Prefix persisted to git config
      result = docker_exec("git -C /root/work/myproject.bare config tfss.prefix")
      expect(result.stdout).to eq("mp")

      # Worktree at correct jira path: /root/work/mp/feat-MP-1
      result = docker_exec("test -f /root/work/mp/feat-MP-1/.git && echo yes || echo no")
      expect(result.stdout).to eq("yes")
    end

    it "errors when prefix is skipped (jira path cannot be constructed)" do
      # myproject.bare has no prefix — user skips the inline prompt
      script = <<~EXPECT
        set timeout 15
        set env(TFSS_FZF_CMD) "grep myproject"
        spawn bash /opt/tfss/scripts/tmux-git-new-repo
        expect "New Repo*"
        send "j"
        expect "Set prefix*"
        send "\\r"
        expect eof
        catch wait result
        exit [lindex $result 3]
      EXPECT
      result = run_wizard_with_expect(script)
      expect(result.stdout).to include("prefix is required")
      expect(result.exit_code).to eq(1)
    end

    it "errors when worktree name is empty" do
      script = <<~EXPECT
        set timeout 15
        set env(TFSS_FZF_CMD) "grep prefixed"
        spawn bash /opt/tfss/scripts/tmux-git-new-repo
        expect "New Repo*"
        send "j"
        expect "Worktree name*"
        send "\\r"
        expect eof
        catch wait result
        exit [lindex $result 3]
      EXPECT
      result = run_wizard_with_expect(script)
      expect(result.stdout).to include("Must Enter a Worktree Name")
      expect(result.exit_code).to eq(1)
    end

    it "errors when jira ID is empty" do
      script = <<~EXPECT
        set timeout 15
        set env(TFSS_FZF_CMD) "grep prefixed"
        spawn bash /opt/tfss/scripts/tmux-git-new-repo
        expect "New Repo*"
        send "j"
        expect "Worktree name*"
        send "feat\\r"
        expect "Jira ID*"
        send "\\r"
        expect eof
        catch wait result
        exit [lindex $result 3]
      EXPECT
      result = run_wizard_with_expect(script)
      expect(result.stdout).to include("Must Enter a Jira ID")
      expect(result.exit_code).to eq(1)
    end

    it "uses the current pane's bare repo when already inside a bare-repo worktree" do
      # px-main is a worktree of prefixed.bare (prefix = px)
      # no TFSS_FZF_CMD needed — bare_dir is detected from TFSS_PANE_PATH
      script = <<~EXPECT
        set timeout 15
        set env(TFSS_PANE_PATH) "/root/work/px-main"
        spawn bash /opt/tfss/scripts/tmux-git-new-repo
        expect "New Repo*"
        send "j"
        expect "Worktree name*"
        send "task\\r"
        expect "Jira ID*"
        send "MP-99\\r"
        expect eof
      EXPECT
      run_wizard_with_expect(script)
      sleep 1

      # Must land relative to prefixed.bare, not selected via fzf
      result = docker_exec("test -f /root/work/px/task-MP-99/.git && echo yes || echo no")
      expect(result.stdout).to eq("yes")
    end
  end

  describe "delete worktree flow (d)" do
    before(:each) do
      docker_exec("rm -rf /root/work/mp-delete-test")
      docker_exec("git -C /root/work/myproject.bare worktree add /root/work/mp-delete-test HEAD 2>/dev/null; true")
    end

    after(:each) do
      docker_exec("git -C /root/work/myproject.bare worktree remove --force /root/work/mp-delete-test 2>/dev/null; true")
      docker_exec("git -C /root/work/myproject.bare worktree prune 2>/dev/null; true")
      docker_exec("tmux kill-session -t mp-delete-test 2>/dev/null; true")
      docker_exec("tmux kill-session -t anchor 2>/dev/null; true")
    end

    it "shows 'd' option in menu when pane is in a bare-repo worktree" do
      script = <<~EXPECT
        set timeout 10
        set env(TFSS_PANE_PATH) "/root/work/mp-delete-test"
        spawn bash /opt/tfss/scripts/tmux-git-new-repo
        expect "New Repo*"
        send "\\r"
        expect eof
      EXPECT
      result = run_wizard_with_expect(script)
      expect(result.stdout).to include("Delete Worktree (d)")
    end

    it "does not show 'd' option when pane is in a normal repo" do
      script = <<~EXPECT
        set timeout 10
        set env(TFSS_PANE_PATH) "/root/work/normal-repo"
        spawn bash /opt/tfss/scripts/tmux-git-new-repo
        expect "New Repo*"
        send "\\r"
        expect eof
      EXPECT
      result = run_wizard_with_expect(script)
      expect(result.stdout).not_to include("Delete Worktree")
    end

    it "does not show 'd' option when pane is not a git repo" do
      script = <<~EXPECT
        set timeout 10
        set env(TFSS_PANE_PATH) "/root/work/not-a-repo"
        spawn bash /opt/tfss/scripts/tmux-git-new-repo
        expect "New Repo*"
        send "\\r"
        expect eof
      EXPECT
      result = run_wizard_with_expect(script)
      expect(result.stdout).not_to include("Delete Worktree")
    end

    it "shows bare repo and worktree paths in confirmation prompt" do
      script = <<~EXPECT
        set timeout 10
        set env(TFSS_PANE_PATH) "/root/work/mp-delete-test"
        set env(TFSS_CURRENT_SESSION) "mp-delete-test"
        spawn bash /opt/tfss/scripts/tmux-git-new-repo
        expect "New Repo*"
        send "d"
        expect "Bare repo*"
        send "\\r"
        expect eof
      EXPECT
      result = run_wizard_with_expect(script)
      expect(result.stdout).to include("myproject.bare")
      expect(result.stdout).to include("mp-delete-test")
    end

    it "aborts silently on empty Enter at confirmation" do
      script = <<~EXPECT
        set timeout 10
        set env(TFSS_PANE_PATH) "/root/work/mp-delete-test"
        set env(TFSS_CURRENT_SESSION) "mp-delete-test"
        spawn bash /opt/tfss/scripts/tmux-git-new-repo
        expect "New Repo*"
        send "d"
        expect "Yes*"
        send "\\r"
        expect eof
        catch wait result
        exit [lindex $result 3]
      EXPECT
      result = run_wizard_with_expect(script)
      expect(result.exit_code).to eq(0)
      exists = docker_exec("test -d /root/work/mp-delete-test && echo yes || echo no")
      expect(exists.stdout).to eq("yes")
    end

    it "aborts on 'yes' (lowercase)" do
      script = <<~EXPECT
        set timeout 10
        set env(TFSS_PANE_PATH) "/root/work/mp-delete-test"
        set env(TFSS_CURRENT_SESSION) "mp-delete-test"
        spawn bash /opt/tfss/scripts/tmux-git-new-repo
        expect "New Repo*"
        send "d"
        expect "Yes*"
        send "yes\\r"
        expect eof
        catch wait result
        exit [lindex $result 3]
      EXPECT
      result = run_wizard_with_expect(script)
      expect(result.exit_code).to eq(0)
      exists = docker_exec("test -d /root/work/mp-delete-test && echo yes || echo no")
      expect(exists.stdout).to eq("yes")
    end

    it "aborts on 'y'" do
      script = <<~EXPECT
        set timeout 10
        set env(TFSS_PANE_PATH) "/root/work/mp-delete-test"
        set env(TFSS_CURRENT_SESSION) "mp-delete-test"
        spawn bash /opt/tfss/scripts/tmux-git-new-repo
        expect "New Repo*"
        send "d"
        expect "Yes*"
        send "y\\r"
        expect eof
        catch wait result
        exit [lindex $result 3]
      EXPECT
      result = run_wizard_with_expect(script)
      expect(result.exit_code).to eq(0)
      exists = docker_exec("test -d /root/work/mp-delete-test && echo yes || echo no")
      expect(exists.stdout).to eq("yes")
    end

    it "errors when only one tmux session exists (nothing deleted)" do
      # Kill the _test_base session so mp-delete-test is the only session
      docker_exec("tmux new-session -ds mp-delete-test -c /root/work/mp-delete-test 2>/dev/null; true")
      docker_exec("tmux kill-session -t _test_base 2>/dev/null; true")
      script = <<~EXPECT
        set timeout 10
        set env(TFSS_PANE_PATH) "/root/work/mp-delete-test"
        set env(TFSS_CURRENT_SESSION) "mp-delete-test"
        spawn bash /opt/tfss/scripts/tmux-git-new-repo
        expect "New Repo*"
        send "d"
        expect "Yes*"
        send "Yes\\r"
        expect eof
      EXPECT
      result = run_wizard_with_expect(script)
      expect(result.stdout).to include("no other session")
      exists = docker_exec("test -d /root/work/mp-delete-test && echo yes || echo no")
      expect(exists.stdout).to eq("yes")
      session = docker_exec("tmux has-session -t mp-delete-test 2>&1; echo $?")
      expect(session.stdout).to end_with("0")
    end

    it "errors when worktree is dirty (session and worktree untouched)" do
      docker_exec("tmux new-session -ds mp-delete-test -c /root/work/mp-delete-test 2>/dev/null; true")
      docker_exec("tmux new-session -ds anchor -c /root/work 2>/dev/null; true")
      docker_exec("touch /root/work/mp-delete-test/dirty-file")
      script = <<~EXPECT
        set timeout 10
        set env(TFSS_PANE_PATH) "/root/work/mp-delete-test"
        set env(TFSS_CURRENT_SESSION) "mp-delete-test"
        spawn bash /opt/tfss/scripts/tmux-git-new-repo
        expect "New Repo*"
        send "d"
        expect "Yes*"
        send "Yes\\r"
        expect eof
      EXPECT
      result = run_wizard_with_expect(script)
      expect(result.stdout + result.stderr).to match(/fatal|error/i)
      exists = docker_exec("test -d /root/work/mp-delete-test && echo yes || echo no")
      expect(exists.stdout).to eq("yes")
      session = docker_exec("tmux has-session -t mp-delete-test 2>&1; echo $?")
      expect(session.stdout).to end_with("0")
    ensure
      docker_exec("rm -f /root/work/mp-delete-test/dirty-file")
    end

    it "removes worktree and kills session when clean and multiple sessions exist" do
      docker_exec("tmux new-session -ds mp-delete-test -c /root/work/mp-delete-test 2>/dev/null; true")
      docker_exec("tmux new-session -ds anchor -c /root/work 2>/dev/null; true")
      script = <<~EXPECT
        set timeout 15
        set env(TFSS_PANE_PATH) "/root/work/mp-delete-test"
        set env(TFSS_CURRENT_SESSION) "mp-delete-test"
        spawn bash /opt/tfss/scripts/tmux-git-new-repo
        expect "New Repo*"
        send "d"
        expect "Yes*"
        send "Yes\\r"
        expect eof
      EXPECT
      run_wizard_with_expect(script)
      sleep 1

      exists = docker_exec("test -d /root/work/mp-delete-test && echo yes || echo no")
      expect(exists.stdout).to eq("no")

      session = docker_exec("tmux has-session -t mp-delete-test 2>&1; echo $?")
      expect(session.stdout).not_to end_with("0")

      bare = docker_exec("test -d /root/work/myproject.bare && echo yes || echo no")
      expect(bare.stdout).to eq("yes")
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
