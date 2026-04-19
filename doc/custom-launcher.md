# Custom Session Launcher

The `@tfss_session_launcher` option lets you replace the default session setup script.

## Contract

The launcher is invoked via `eval` from `tmux-git` and `tmux-git-new-repo`:

```bash
eval "$session_launcher $session $session_dir"
```

**Arguments:**
- `$1` — tmux session name (already created, detached, with window `0` named `localhost`)
- `$2` — absolute path to the repo directory

**Preconditions when called:**
- Session exists and is detached (`tmux new-session -ds`)
- Window `0` named `localhost` exists with cwd `$session_dir`
- Caller is inside tmux (`$TMUX` may or may not be set)

**Expected behavior:**
- Set up windows/panes as desired
- Switch the client to the session: `tmux switch-client -t "$session"` (inside tmux) or `tmux attach-session -t "$session"` (outside)

**No required exit code.** Script runs in the caller's shell context via `eval`.

## Default Launcher Behavior

`scripts/tfss-default-session-launcher` does:
1. Creates window `2` named `ide2` in cwd `$session_dir`
2. If `@tfss_session_window_split == "1"`: splits window `2` horizontally
3. If `@tfss_session_vim_cmd` set: sends `$vim_cmd $vim_options` + Enter to pane `2.0`
4. Kills window `0` (the initial `localhost` window)
5. Switches client to `${session}:2.0`

## Example: Minimal Custom Launcher

```bash
#!/usr/bin/env bash
session=$1
session_dir=$2

tmux new-window -t "${session}:1" -c "$session_dir"
tmux kill-window -t "${session}:0"
tmux switch-client -t "${session}:1"
```

Configure it:
```
set -g @tfss_session_launcher "/path/to/my-launcher"
```

## Notes

- Launcher must be executable
- Path must be absolute (no `~` expansion — use `$HOME`)
- Can include arguments in the option value (they precede `$session $session_dir`)
- Symlink resolution is not required in custom launchers unless they need to find plugin files
