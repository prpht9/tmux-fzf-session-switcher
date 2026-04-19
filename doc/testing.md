# Testing

## Overview

Integration tests run inside a Docker container (Ubuntu 24.04) with tmux, fzf, fd, ruby, git, and expect installed. The host runs RSpec which orchestrates tests via `docker exec`. This ensures tests never touch your live tmux session.

## Prerequisites

- Docker (or Rancher Desktop)
- Ruby + Bundler on the host

## Quick Start

```bash
bundle install          # one-time: install rspec + rake
rake test:up            # build image + start container
rake test               # run all specs
rake test:down          # stop + remove container
```

Run a single spec file:

```bash
bundle exec rspec test/spec/fd_discovery_spec.rb --format documentation
```

## Rake Tasks

| Task | Description |
|------|-------------|
| `rake test` | Run all integration specs |
| `rake test:up` | Build Docker image and start container |
| `rake test:down` | Stop and remove container |
| `rake test:build` | Build Docker image only |
| `rake test:integration` | Run specs (alias used by `rake test`) |

## Architecture

```
Host (macOS)                          Container (Ubuntu 24.04)
┌─────────────────┐                  ┌──────────────────────────┐
│ rake test        │                  │ tmux server (headless)   │
│   └─ rspec       │  docker exec    │   ├─ fzf                 │
│       └─ shell ──┼─────────────────┼─► ├─ fd                  │
│         out ◄────┼─────────────────┼── ├─ ruby                │
│         assert   │                  │   └─ git fixtures        │
└─────────────────┘                  └──────────────────────────┘
```

The project directory is bind-mounted into the container at `/opt/tfss`. The container runs `sleep infinity` and stays alive between test runs. RSpec specs call `docker exec tfss-test bash -c '...'` to execute commands inside the container.

## How It Works

### Docker Image (`test/Dockerfile`)

Installs fd and fzf from GitHub releases (matching the latest versions) plus tmux, git, ruby, expect, and bc from apt. Configures a `.tmux.conf` that sources the plugin with `@tfss_repo_path` set to `/root/work`.

### Fixture Setup (`test/helpers/fixture_helpers.sh`)

Runs once per test suite (via RSpec `before(:suite)`). Creates a git fixture tree under `/root/work/`:

| Path | Type | Purpose |
|------|------|---------|
| `normal-repo/` | git repo (`.git/` dir) | Standard repo discovery |
| `dotted.repo/` | git repo (`.git/` dir) | Tests `.` → `_` session naming |
| `org/proj/nested-repo/` | git repo at depth 3 | Tests max-depth 4 boundary |
| `myproject.bare/` | bare clone | Tests bare repo exclusion from fd |
| `mp-main/` | worktree (`.git` file) | Tests worktree discovery |
| `mp-feature/` | worktree (`.git` file) | Tests worktree discovery |
| `not-a-repo/` | plain directory | Must NOT appear in fd results |
| `too/deep/a/b/c/repo/` | git repo at depth 6 | Must NOT appear at max-depth 4 |

### Test Helpers (`test/helpers/tmux_helpers.sh`)

Bash functions sourced inside the container: `start_test_tmux`, `stop_test_tmux`, `wait_for`, `assert_session_exists`, `capture_pane`, etc.

### Spec Helper (`test/spec/spec_helper.rb`)

The `DockerHelper` module wraps `docker exec` calls and provides convenience methods: `docker_exec`, `start_tmux`, `stop_tmux`, `fd_repos`, `run_tmux_git`, `run_session_switcher_input`, `run_session_launcher`.

## Spec Files

### `fd_discovery_spec.rb`

Tests the `fd --hidden --max-depth 4 '^.git$'` command that powers repo discovery. Verifies correct inclusion of normal repos, worktrees, nested repos and correct exclusion of bare repos, non-repos, and too-deep repos.

### `repo_selector_spec.rb` (C-a f)

Tests `scripts/tmux-git`:
- Session creation for normal repos and worktrees
- Session name derivation (dots converted to underscores)
- Working directory set correctly
- Reattach to existing sessions without duplication
- Custom session launcher invocation
- `TFSS_FZF_CMD` env var for non-interactive fzf selection
- Clean exit on empty selection

### `session_switcher_spec.rb` (C-a b)

Tests `scripts/session-switcher-fzf-input`:
- Lists all active sessions
- `@last_session` appears first in output
- No duplication of last session
- Graceful handling of missing `@last_session`
- Updates `@last_session` after execution
- Full pipeline (script → fzf filter → switch-client)

### `session_launcher_spec.rb`

Tests `scripts/tfss-default-session-launcher`:
- Creates `ide2` window
- Kills initial `localhost` window
- Horizontal split when `@tfss_session_window_split=1`
- Vim command sent when configured

### `new_repo_wizard_spec.rb` (C-a n)

Tests `scripts/tmux-git-new-repo` using `expect` for interactive input:
- **New repo (n)**: creates directory with `.git`, creates tmux session
- **Normal clone (c)**: clones repo, creates session
- **Bare clone (b)**: creates `.bare` directory + worktree, session in worktree
- **Worktree (w)**: adds worktree to existing bare repo
- Empty choice exits cleanly
- Invalid choice shows error
- Empty required input shows error

## Production Code Change for Testability

A single env var `TFSS_FZF_CMD` was added to two scripts to allow non-interactive fzf selection in tests:

- `scripts/tmux-git:19` — `fzf` → `${TFSS_FZF_CMD:-fzf}`
- `scripts/tmux-git-new-repo:82` — `fzf-tmux --reverse` → `${TFSS_FZF_CMD:-fzf-tmux --reverse}`

When `TFSS_FZF_CMD` is unset (normal usage), behavior is identical. Tests set it to commands like `fzf -f <query> | head -1` or `head -1` for automated selection.
