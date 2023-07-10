#!/usr/bin/env bash

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
[[ ! -d $HOME/bin ]] && mkdir $HOME/bin
ln -s "$CURRENT_DIR/scripts/tmux-git" $HOME/bin/tmux-git
