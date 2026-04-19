# TMux FZF Session Switcher

## What This Is

A tmux plugin for fuzzy-search session switching and git repo management. Three key bindings:
- `<prefix>f` — fuzzy search git repos under `$HOME/work`, create/attach tmux sessions
- `<prefix>b` — switch between open tmux sessions (last visited first)
- `<prefix>n` — interactive new repo / clone workflow

## Release

```bash
rake release  # Creates GitHub release from VERSION + CHANGELOG
```

```bash
rake test       # Runs RSpec integration tests in Docker container
rake test:up    # Build image + start container
rake test:down  # Stop container
```

## Architecture

All config values are tmux options read via `get_tmux_option()` in `env.sh`, which every script sources.

| File | Role |
|------|------|
| `tmux-fzf-session-switcher.tmux` | Plugin entry point — registers all tmux key bindings |
| `env.sh` | Shared defaults and `get_tmux_option()` helper |
| `scripts/tmux-git` | Repo finder: `fd` searches for `.git`, fzf selects, creates/attaches session |
| `scripts/tmux-git-new-repo` | Interactive new-repo wizard (new / bare clone / normal clone / worktree) |
| `scripts/session-switcher-fzf-input` | Ruby: builds session list with `@last_session` pinned first |
| `scripts/tfss-default-session-launcher` | Default session initializer (optional vim + pane split) |
| `tmux-git-cli-install.sh` | Symlinks `scripts/tmux-git` into `$HOME/bin` for CLI use |

## Docs

| File | Topic |
|------|-------|
| [doc/custom-launcher.md](doc/custom-launcher.md) | `@tfss_session_launcher` contract, arguments, and examples |
| [doc/bare-repo-worktree.md](doc/bare-repo-worktree.md) | Bare clone + worktree setup and naming conventions |
| [doc/testing.md](doc/testing.md) | Test infrastructure, spec coverage, and Docker setup |

## Key Conventions

- Session names: `basename` of repo dir with `.` → `_` (`tr . _`)
- Scripts resolve symlinks to find `CURRENT_DIR` before sourcing `env.sh`
- Bare repo / worktree support: `fd` searches depth ≤ 4 for `.git` files and dirs
- Ruby scripts run with `ruby --disable=gems` for speed
- Config keys: `@tfss_repo_path` (default `$HOME/work`), `@tfss_repo_selector_key`, `@tfss_session_switcher_key`, `@tfss_new_repo_key`, `@tfss_session_window_split`, `@tfss_session_vim_cmd`, `@tfss_session_launcher`
- Per-project prefix: `git config --local tfss.prefix <short>` in bare repos — auto-prepended to worktree names during creation
