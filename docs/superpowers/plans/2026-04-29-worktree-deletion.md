# Worktree Deletion (`d`) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a `d` option to the `<prefix>n` menu that removes the current bare-repo worktree and its tmux session.

**Architecture:** All logic lives in `scripts/tmux-git-new-repo`. Detection runs at script entry using `git rev-parse --git-common-dir`; if the result ends in `.bare`, the session is in a bare-repo worktree and `d` is appended to the menu. The `d` case collects confirmation, checks session count, runs `git worktree remove` (no `--force`), then switches to the last session and kills the current one.

**Tech Stack:** bash, git, tmux, expect (tests), RSpec (test runner)

---

## File Map

| File | Change |
|------|--------|
| `scripts/tmux-git-new-repo` | Add detection block, dynamic menu, `d` case |
| `test/spec/new_repo_wizard_spec.rb` | Add `describe "delete worktree flow (d)"` block |

---

### Task 1: Write failing tests for menu gating

**Files:**
- Modify: `test/spec/new_repo_wizard_spec.rb`

- [ ] **Step 1: Add `describe "delete worktree flow (d)"` block with menu gating tests**

Add after the `"set prefix flow (p)"` describe block:

```ruby
describe "delete worktree flow (d)" do
  before(:each) do
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
      expect "Delete Worktree*"
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
end
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
bundle exec rspec test/spec/new_repo_wizard_spec.rb -e "delete worktree" --format documentation
```

Expected: FAIL — `"Delete Worktree (d)"` not found in menu output (feature not implemented yet).

---

### Task 2: Implement worktree detection and dynamic menu

**Files:**
- Modify: `scripts/tmux-git-new-repo`

- [ ] **Step 1: Add detection block and dynamic menu after the config reads**

The current file has these lines near the top (after sourcing env.sh):

```bash
repo_path=$(get_tmux_option "@tfss_repo_path" "$default_repo_path")
session_launcher=$(get_tmux_option "@tfss_session_launcher" "$default_session_launcher")

read -n1 -r -p "New Repo (n), Bare Clone (b), Clone (c), Worktree (w) or Prefix (p)? " flow_choice
```

Replace that block with:

```bash
repo_path=$(get_tmux_option "@tfss_repo_path" "$default_repo_path")
session_launcher=$(get_tmux_option "@tfss_session_launcher" "$default_session_launcher")

_pane_path="${TFSS_PANE_PATH:-$(tmux display-message -p '#{pane_current_path}' 2>/dev/null)}"
_bare_dir=$(git -C "$_pane_path" rev-parse --git-common-dir 2>/dev/null)
_worktree_root=$(git -C "$_pane_path" rev-parse --show-toplevel 2>/dev/null)
_in_bare_worktree=0
if [[ -n $_bare_dir && $_bare_dir == *.bare ]]; then
  _in_bare_worktree=1
fi

_menu="New Repo (n), Bare Clone (b), Clone (c), Worktree (w) or Prefix (p)"
if [[ $_in_bare_worktree -eq 1 ]]; then
  _menu="${_menu} or Delete Worktree (d)"
fi
read -n1 -r -p "${_menu}? " flow_choice
```

- [ ] **Step 2: Run tests to verify menu gating tests pass**

```bash
bundle exec rspec test/spec/new_repo_wizard_spec.rb -e "shows 'd' option" --format documentation
bundle exec rspec test/spec/new_repo_wizard_spec.rb -e "does not show 'd' option" --format documentation
```

Expected: PASS for all three menu gating tests.

- [ ] **Step 3: Run full wizard spec to verify no regressions**

```bash
bundle exec rspec test/spec/new_repo_wizard_spec.rb --format documentation
```

Expected: all previously passing tests still pass.

- [ ] **Step 4: Commit**

```bash
git add scripts/tmux-git-new-repo test/spec/new_repo_wizard_spec.rb
git commit -m "feat: detect bare-repo worktree and gate 'd' option in menu"
```

---

### Task 3: Write failing tests for `d` confirmation prompt

**Files:**
- Modify: `test/spec/new_repo_wizard_spec.rb`

- [ ] **Step 1: Add confirmation tests inside the existing `describe "delete worktree flow (d)"` block**

Add after the three menu gating tests, still inside the describe block:

```ruby
it "shows bare repo and worktree paths in confirmation prompt" do
  script = <<~EXPECT
    set timeout 10
    set env(TFSS_PANE_PATH) "/root/work/mp-delete-test"
    set env(TFSS_CURRENT_SESSION) "mp-delete-test"
    spawn bash /opt/tfss/scripts/tmux-git-new-repo
    expect "New Repo*"
    send "d"
    expect "Bare repo*"
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
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
bundle exec rspec test/spec/new_repo_wizard_spec.rb -e "confirmation" --format documentation
bundle exec rspec test/spec/new_repo_wizard_spec.rb -e "aborts" --format documentation
bundle exec rspec test/spec/new_repo_wizard_spec.rb -e "bare repo and worktree" --format documentation
```

Expected: FAIL — `d` case not implemented yet.

---

### Task 4: Write failing tests for deletion sequence

**Files:**
- Modify: `test/spec/new_repo_wizard_spec.rb`

- [ ] **Step 1: Add deletion sequence tests inside `describe "delete worktree flow (d)"`**

Add after the confirmation tests:

```ruby
it "errors when only one tmux session exists (nothing deleted)" do
  # Only one session: mp-delete-test itself; no anchor session created
  docker_exec("tmux new-session -ds mp-delete-test -c /root/work/mp-delete-test 2>/dev/null; true")
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
  # git worktree remove prints an error about untracked files
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

  # Worktree directory is gone
  exists = docker_exec("test -d /root/work/mp-delete-test && echo yes || echo no")
  expect(exists.stdout).to eq("no")

  # tmux session is gone
  session = docker_exec("tmux has-session -t mp-delete-test 2>&1; echo $?")
  expect(session.stdout).not_to end_with("0")

  # Bare repo is still intact
  bare = docker_exec("test -d /root/work/myproject.bare && echo yes || echo no")
  expect(bare.stdout).to eq("yes")
end
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
bundle exec rspec test/spec/new_repo_wizard_spec.rb -e "only one tmux session" --format documentation
bundle exec rspec test/spec/new_repo_wizard_spec.rb -e "worktree is dirty" --format documentation
bundle exec rspec test/spec/new_repo_wizard_spec.rb -e "removes worktree and kills session" --format documentation
```

Expected: FAIL — `d` case not implemented.

---

### Task 5: Implement the `d` case

**Files:**
- Modify: `scripts/tmux-git-new-repo`

- [ ] **Step 1: Add TFSS_CURRENT_SESSION override and `d` case to the case statement**

The current `case $flow_choice in` block ends with:

```bash
  *)
    echo "Repo Command Invalid"
    exit 1
    ;;
esac
```

Add the `d` case before the `*)` catch-all:

```bash
  d) # delete current bare-repo worktree and its tmux session
    current_session="${TFSS_CURRENT_SESSION:-$(tmux display-message -p '#S' 2>/dev/null)}"

    echo
    echo "Bare repo:  $_bare_dir"
    echo "Worktree:   $_worktree_root"
    echo
    read -r -p 'Type "Yes" to confirm deletion [N]: ' _confirm
    if [[ $_confirm != "Yes" ]]; then
      exit 0
    fi

    session_count=$(tmux list-sessions 2>/dev/null | wc -l | tr -d ' ')
    if [[ $session_count -le 1 ]]; then
      echo "Cannot delete: no other session to switch to"
      exit 1
    fi

    if ! git -C "$_bare_dir" worktree remove "$_worktree_root"; then
      exit 1
    fi

    if [[ -n $TMUX ]]; then
      tmux switch-client -l
    fi
    tmux kill-session -t "$current_session"
    exit 0
    ;;
```

- [ ] **Step 2: Run all new tests**

```bash
bundle exec rspec test/spec/new_repo_wizard_spec.rb -e "delete worktree" --format documentation
```

Expected: all 10 `d` tests pass.

- [ ] **Step 3: Run full wizard spec to verify no regressions**

```bash
bundle exec rspec test/spec/new_repo_wizard_spec.rb --format documentation
```

Expected: all tests pass.

- [ ] **Step 4: Run full test suite**

```bash
rake test
```

Expected: all specs pass.

- [ ] **Step 5: Commit**

```bash
git add scripts/tmux-git-new-repo test/spec/new_repo_wizard_spec.rb
git commit -m "feat: add 'd' option to delete current bare-repo worktree and session"
```
