#!/usr/bin/env bash
# Shared tmux helper functions for integration tests.
# Source this file: source /opt/tfss/test/helpers/tmux_helpers.sh

# Start a clean tmux server with a base session
start_test_tmux() {
  tmux kill-server 2>/dev/null || true
  sleep 0.3
  tmux new-session -d -s _test_base -c /root
}

# Tear down the tmux server
stop_test_tmux() {
  tmux kill-server 2>/dev/null || true
}

# Poll until a condition is true or timeout (seconds) is reached.
# Usage: wait_for "tmux has-session -t mysession" 10
wait_for() {
  local condition="$1"
  local timeout="${2:-10}"
  local interval=0.2
  local elapsed=0

  while ! eval "$condition" 2>/dev/null; do
    sleep "$interval"
    elapsed=$(echo "$elapsed + $interval" | bc)
    if (( $(echo "$elapsed >= $timeout" | bc -l) )); then
      echo "TIMEOUT waiting for: $condition" >&2
      return 1
    fi
  done
}

# Assert a tmux session exists
assert_session_exists() {
  local name="$1"
  if tmux has-session -t="$name" 2>/dev/null; then
    echo "PASS: session '$name' exists"
    return 0
  else
    echo "FAIL: session '$name' does not exist" >&2
    tmux list-sessions 2>/dev/null >&2 || true
    return 1
  fi
}

# Assert a tmux session does NOT exist
assert_no_session() {
  local name="$1"
  if tmux has-session -t="$name" 2>/dev/null; then
    echo "FAIL: session '$name' exists but should not" >&2
    return 1
  else
    echo "PASS: session '$name' does not exist"
    return 0
  fi
}

# Get the working directory of a session's active pane
get_session_cwd() {
  local name="$1"
  tmux display-message -t "$name" -p '#{pane_current_path}'
}

# Capture visible pane contents to stdout
capture_pane() {
  local target="$1"
  tmux capture-pane -t "$target" -p
}

# Count sessions matching a name
count_sessions() {
  local name="$1"
  tmux list-sessions -F '#{session_name}' 2>/dev/null | grep -c "^${name}$" || echo 0
}
