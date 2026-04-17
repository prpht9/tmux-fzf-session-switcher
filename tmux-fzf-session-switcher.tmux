#!/usr/bin/env bash

export CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

source "$CURRENT_DIR/env.sh"

set_repo_selector_bindings() {
  local key_bindings=$(get_tmux_option "$tfss_repo_selector_key" "$default_repo_selector_key")
  local key
  for key in $key_bindings; do
    tmux bind-key "$key" new-window -n "tmux-git" "$CURRENT_DIR/scripts/tmux-git"
  done
}

set_session_switcher_bindings() {
  local key_bindings=$(get_tmux_option "$tfss_session_switcher_key" "$default_session_switcher_key")
  local key
  for key in $key_bindings; do
    tmux bind-key "$key" \
      new-window -n "session-switcher" \
        "$CURRENT_DIR/scripts/session-switcher-fzf-input | fzf | { read session && tmux switch-client -t \"\$session\"; }"
  done
}

set_new_repo_bindings() {
  local key_bindings=$(get_tmux_option "$tfss_new_repo_key" "$default_new_repo_key")
  local key
  for key in $key_bindings; do
    tmux bind-key "$key" new-window -n "tmux-git-new-repo" "$CURRENT_DIR/scripts/tmux-git-new-repo"
  done
}

set_repo_selector_bindings
set_session_switcher_bindings
set_new_repo_bindings
