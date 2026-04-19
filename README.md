# Tmux fzf session switcher plugin

This plugin offers three options for auto loading and switching sessions attached to your git repos.

The first option allows you to fzf search all your `@tfss_repo_path` subdirectories which contain a `.git` repo directory or a `.git` worktree file and then start a new tmux session named exactly the same as the directory. This specifically conforms to the use of worktrees if you create the bare repo in your `@tfss_repo_path`, then create the worktrees using `git worktree add ../WORKTREE_NAME`. If your bare repo is called `hello-world.bare` then you might name your worktree `hw-WORKTREE_NAME` in order to associate them with the parent repo. Otherwise the worktree names will overlap with other repos, making them more difficult to find. Using the bare repos ensures they won't show up as sessions to work in because they don't have a `.git` directory or `.git` file.

The second option is for use once you have some open sessions, allowing you to specifically jump between your open sessions. It uses a tmux variable named `@last_session` to store the last session you jumped to in order to place it at the top of the fzf list. This is handy when you have lots of repos with similar names to allow you to have the shortest fzf searches possible when you know the repo is already open. Use of the first method can just jump you to the already opened session as well if you forgot it was open.

The third option is an interactive wizard for creating new repos, cloning bare repos with worktrees, cloning normal repos, or adding a worktree to an existing bare repo.

## Dependencies

This project requires [fzf](https://github.com/junegunn/fzf), [fd](https://github.com/sharkdp/fd) and [ruby](https://www.ruby-lang.org/) in your `$PATH`. We recommend the most up-to-date version of fzf. `fd` is required because `find` is too slow hunting through all the files/directories.

For running the test suite: [Docker](https://www.docker.com/) (or [Rancher Desktop](https://rancherdesktop.io/)) and Ruby with Bundler on the host.

# Install

## Manually

For this method you can git clone the repo and just execute the following from the root of the project:

```
./tmux-fzf-session-switcher.tmux
```

## TPM - Tmux Package Manager

Add the following line to your `.tmux.conf`:

```
set -g @plugin 'prpht9/tmux-fzf-session-switcher'
```

Then execute `<prefix>I` within your tmux session to install or `<prefix>U` to update.

# TFSS Configuration

The following option defaults are:

```
@tfss_repo_selector_key=f
@tfss_repo_path="$HOME/work"
@tfss_session_switcher_key=b
@tfss_session_window_split=0
@tfss_session_vim_cmd=''
@tfss_session_vim_options=''
@tfss_session_launcher="~/.tmux/plugins/tmux-fzf-session-switcher/scripts/tfss-default-session-launcher"
```

All of these can be overridden. Here is an example where we prefer to perform 1 window split for 2 panes, set our vim command to `vi` and add `-S .session.vim` to the auto execution of the vim command so it will auto load pane 0 with vim and load all your open buffers from a previous `:mks! .session.vim` ex command.

```
set -g @tfss_session_window_split '1'
set -g @tfss_session_vim_cmd 'vi'
set -g @tfss_session_vim_options '-S .session.vim'
```

You can also change your repo search path with:

```
set -g @tfss_repo_path "~/workspace"
```

And change your key bindings with:

```
set -g @tfss_repo_selector_key "r"
set -g @tfss_session_switcher_key "s"
```

However, if you use `<leader>f` and `<leader>b` in vim, aligning the keys for opening repos with opening files and selecting sessions with selecting buffers will create some really good muscle memory reinforcement. [KEEPING DEFAULT 'f' AND 'b' IS HIGHLY RECOMMENDED IN THIS SCENARIO] (or at least match them up with whatever keys you use for FZF `:Files` and `:Buffers` in vim)

If you don't like the way we launch sessions, just write your own script and configure it with:

```
set -g @tfss_session_launcher "~/bin/tfss-session-launcher"
```

## Optional tmux-git for launching repos from cli

There is a script which will install a link to tmux-git in the scripts directory to your `$HOME/bin` directory. Just execute:

```
$HOME/.tmux/plugins/tmux-fzf-session-switcher/tmux-git-cli-install.sh
```

# Usage

I come from the vim world and use fzf `:Buffers` and `:Files` to jump between open buffers with `<leader>b` and open new files with `<leader>f`. So this plugin follows the same idea:

- `<prefix>b` — jump between sessions; the last session you were in is placed at the top to allow `<prefix>b<CR>` to go to your last session quickly
- `<prefix>f` — fzf search all git repo directories in your `@tfss_repo_path` and create or attach to a session
- `<prefix>n` — interactive wizard to create a new repo, clone a bare repo, clone a normal repo, or add a worktree

# Testing

Tests run inside a Docker container to avoid interfering with your live tmux session. See [doc/testing.md](doc/testing.md) for full details.

```bash
bundle install
rake test:up    # build image + start container
rake test        # run all specs
rake test:down   # stop container
```
