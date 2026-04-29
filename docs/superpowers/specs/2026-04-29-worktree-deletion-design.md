# Worktree Deletion (`d`) — Design Spec

**Date:** 2026-04-29
**Branch:** tfss-worktree_removal

## Summary

Add a `d` option to the `<prefix>n` menu that deletes the current bare-repo worktree: closes the tmux session and removes the worktree directory. Only visible when the current session is inside a bare-repo worktree.

## Scope

Single file change: `scripts/tmux-git-new-repo`. No new scripts, no new `env.sh` helpers.

---

## Detection & Menu Gating

At script entry, before building the prompt string, detect the current pane's context:

```bash
pane_path=$(tmux display-message -p '#{pane_current_path}')
bare_dir=$(git -C "$pane_path" rev-parse --git-common-dir 2>/dev/null)
worktree_root=$(git -C "$pane_path" rev-parse --show-toplevel 2>/dev/null)
```

A session is in a bare-repo worktree when `$bare_dir` ends in `.bare`. Only then is `d` appended to the menu prompt. If not in a bare-repo worktree, the menu shows the existing options unchanged.

---

## Confirmation Prompt

When `d` is selected, display:

```
Bare repo:  /Users/you/work/myproject.bare
Worktree:   /Users/you/work/mp-fix-login

Type "Yes" to confirm deletion [N]:
```

- Only exact string `Yes` + Enter proceeds.
- Anything else (empty Enter, `y`, `yes`, `YES`) exits silently with no action.
- User remains in their session on abort.

---

## Deletion Sequence

`$current_session` is captured upfront via `tmux display-message -p '#S'`.

1. Check session count: if this is the only tmux session, print an error ("Cannot delete: no other session to switch to") and exit. Nothing is deleted.
2. `git -C "$bare_dir" worktree remove "$worktree_root"`
   - If this fails (dirty tree, open stash, uncommitted changes): print the git error and exit. Tmux session is untouched. User can recover work.
   - No `--force` flag, ever.
3. `tmux switch-client -l` — jump to last visited session.
4. `tmux kill-session -t "$current_session"` — kills all windows, panes, and the session.

Git runs first so a dirty worktree is a hard stop before any tmux state is destroyed.

---

## Non-Goals

- No fzf picker for selecting which worktree to delete — always operates on current session only.
- No `--force` escape hatch.
- No support for deleting worktrees from normal (non-bare) repos.
