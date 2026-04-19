# Bare Repo + Worktree Workflow

Git worktrees let you check out multiple branches simultaneously as separate directories. Pairing a bare clone with worktrees gives each branch its own tmux session with no stashing.

## Initial Setup (`<prefix>n` → `b`)

Prompts:
1. **Bare Repo URL** — the remote to clone
2. **New Bare Repo Location** — path relative to `$HOME` (convention: end with `.bare`)
3. **New Worktree Name** — name of the first worktree to create

Example inputs:
```
Bare Repo URL: git@github.com:org/myproject.git
New Bare Repo Location: work/myproject.bare
New Worktree Name: mp-main
```

Result on disk:
```
~/work/
  myproject.bare/     ← bare clone (a .git dir with no working tree)
  mp-main/            ← worktree checked out to default branch
```

The session opens in `mp-main/`.

## Adding More Worktrees (`<prefix>n` → `w`)

Searches `@tfss_repo_path` for directories ending in `.bare`, lets you pick one via fzf, then prompts for a worktree name.

Example:
```
Select bare repo: ~/work/myproject.bare
Enter worktree name: mp-feature-auth
```

Result:
```
~/work/
  myproject.bare/
  mp-main/
  mp-feature-auth/    ← new worktree on a new branch
```

## How `fd` Finds These Repos

`fd --hidden --max-depth 4 '^\.git$'` matches both:
- `.git` **directories** — normal repos and worktrees (each has a `.git` dir pointing back to bare)
- `.git` **files** — bare repo root contains a plain `.git` file

So `<prefix>f` can jump to any worktree directory directly.

## Worktree Prefix

Store a short prefix per bare repo via git config:

```bash
git -C ~/work/myproject.bare config --local tfss.prefix mp
```

When creating worktrees (`<prefix>n` → `w`), the prompt auto-prepends the prefix:

```
Enter worktree name [mp-]: fix-login
# Creates: ~/work/mp-fix-login/
```

Set during bare clone (`<prefix>n` → `b`) or later (`<prefix>n` → `p`).

If you type a name already starting with the prefix (e.g., `mp-fix-login`), it won't double-prefix.

## Naming Convention

Use a short prefix tied to the project for worktree names. If the bare repo is `myproject.bare`, name worktrees `mp-BRANCH` (e.g., `mp-main`, `mp-fix-login`). This keeps sessions identifiable and prevents name collisions with other repos in the same directory.

## Session Names

Session name = `basename` of worktree dir with `.` → `_`. So:
- `mp-main` → session `mp-main`
- `mp-feature-auth` → session `mp-feature-auth`
- `my.project` → session `my_project`
