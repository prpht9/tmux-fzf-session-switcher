#!/usr/bin/env bash

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
tmux bind-key "f" new-window -n "tmux-git" "$CURRENT_DIR/scripts/tmux-git"
tmux bind-key "b" \
  new-window -n "session-switcher" \
    "$CURRENT_DIR/scripts/session-switcher-fzf-input | fzf | xargs tmux switch-client -t"

