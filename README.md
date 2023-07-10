# Tmux fzf session switcher plugin

This plugin offers up two options for auto loading and switching sessions attached to your git repos.

The first option, allows you to fzf search all your $WORK subdirectories which contain a '.git' directory and then start a new tmux session named exactly the same as the directory.  This specifically conforms to the use of worktrees if you create the bare repo in your $WORK path, then create the worktrees using `git worktree add WORKTREE_NAME`.  if your bare repo is called hello-world.bare then you might name your worktree `hw-WORKTREE_NAME` in order to associate them with the parent repo.  Also, using this method the bare repos don't show up as sessions to work in because they don't have a '.git' directory. 

The second option is for use once you have some open sessions allowing you to specifically jump between your open sessions. It uses a tmux variable named '@last_session' to store the last session you jumped to in order to place it at the top of the fzf list.

## Dependencies

This project requires [fzf]|(https://github.com/junegunn/fzf) and [ruby]|(https://www.ruby-lang.org/) in your '$PATH'.  We recommend the most up-to-date version of fzf.  But ruby doesn't really matter.  It was just easier to parse and format the input via ruby than shell.

## Install

### Manually

For this method you can git clone the repo and just execute the following from the root of the project:

``
./tmux-fzf-session-switcher.tmux
``

### TPM - Tmux Package Manager

Add the following line to your `.tmux.conf`:

``
set -g @plugin 'prpht9/tmux-fzf-session-switcher'
``

Then execute `<prefix>I` within your tmux session.

### Optional tmux-git for launching repos from cli

There is a script which will install a link to tmux-git in the scripts directory to your '$HOME/bin' directory.  Just go execute:

``
$HOME/.tmux/plugins/tmux-fzf-session-switcher/tmux-git-cli-install.sh
``

## Usage

I come from the vim world and use fzf :Buffers and :Files to jump between open buffers with `<leader>b` and open new files with `<leader>f`.  So this plugin follows the same idea, you can jump between sessions using `<prefix>b` where the last session you were in is placed at the top to allow `<prefix>b<CR>` to go to your last session without having to use the other two key combos already mapped for that action.  then your one key combo is the same whether you jump to your last session or decide to start fuzzy searching for a different one.  Similarly `<prefix>f` brings up the entire list of git repo directories in your $WORK directory for fuzzy searching and creation of a new session on that repo.

