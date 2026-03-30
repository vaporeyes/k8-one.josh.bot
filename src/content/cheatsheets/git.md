---
title: "Git"
description: "Quick reference for everyday git workflows, branching, history, and recovery."
updatedDate: 2026-03-30
---

## Config

```bash
# Identity
git config --global user.name "Your Name"
git config --global user.email "you@example.com"

# Default branch
git config --global init.defaultBranch main

# Aliases
git config --global alias.co checkout
git config --global alias.br branch
git config --global alias.st status
git config --global alias.lg "log --oneline --graph --all"

# Editor
git config --global core.editor "vim"

# View all config
git config --list --show-origin
```

## Basics

```bash
# Init
git init
git clone https://github.com/user/repo.git

# Status
git status
git status -s              # short format

# Stage
git add file.txt
git add src/               # directory
git add -p                 # interactive hunk staging

# Commit
git commit -m "message"
git commit -am "message"   # stage tracked + commit
git commit --amend         # edit last commit

# Diff
git diff                   # unstaged changes
git diff --staged          # staged changes
git diff main..feature     # between branches
git diff HEAD~3..HEAD      # last 3 commits
```

## Branching

```bash
# List branches
git branch                 # local
git branch -r              # remote
git branch -a              # all

# Create and switch
git checkout -b feature
git switch -c feature      # modern equivalent

# Switch
git checkout main
git switch main

# Delete branch
git branch -d feature      # safe (merged only)
git branch -D feature      # force

# Delete remote branch
git push origin --delete feature

# Rename current branch
git branch -m new-name

# Track remote branch
git branch --set-upstream-to=origin/main main
```

## Merging and Rebasing

```bash
# Merge
git merge feature
git merge --no-ff feature  # always create merge commit

# Abort merge
git merge --abort

# Rebase
git rebase main            # replay current branch onto main
git rebase -i HEAD~3       # interactive rebase last 3 commits

# Abort rebase
git rebase --abort

# Continue after resolving conflicts
git rebase --continue

# Cherry-pick
git cherry-pick abc1234
git cherry-pick abc1234..def5678   # range
```

## Remote

```bash
# List remotes
git remote -v

# Add remote
git remote add origin https://github.com/user/repo.git

# Fetch
git fetch origin
git fetch --all            # all remotes
git fetch --prune          # remove deleted remote branches

# Pull
git pull                   # fetch + merge
git pull --rebase          # fetch + rebase

# Push
git push origin main
git push -u origin feature # set upstream
git push --force-with-lease # safer force push
```

## Log and History

```bash
# Log
git log
git log --oneline
git log --oneline --graph --all
git log --stat             # files changed per commit
git log -p                 # full diffs
git log -n 5               # last 5 commits
git log --since="2 weeks ago"
git log --author="josh"

# Search commits
git log --grep="fix bug"
git log -S "functionName"  # commits that add/remove string
git log -- path/to/file    # history of specific file

# Show commit
git show abc1234
git show HEAD~2:file.txt   # file at specific commit

# Blame
git blame file.txt
git blame -L 10,20 file.txt  # specific lines
```

## Stash

```bash
# Stash changes
git stash
git stash -m "work in progress"
git stash --include-untracked

# List stashes
git stash list

# Apply
git stash pop              # apply and remove
git stash apply            # apply and keep
git stash apply stash@{2}  # specific stash

# Show stash contents
git stash show -p stash@{0}

# Drop
git stash drop stash@{0}
git stash clear            # drop all
```

## Undo and Recovery

```bash
# Unstage file
git restore --staged file.txt
git reset HEAD file.txt    # older syntax

# Discard working changes
git restore file.txt
git checkout -- file.txt   # older syntax

# Undo last commit (keep changes staged)
git reset --soft HEAD~1

# Undo last commit (keep changes unstaged)
git reset HEAD~1

# Undo last commit (discard changes)
git reset --hard HEAD~1

# Revert a commit (creates new commit)
git revert abc1234

# Recover deleted branch / lost commit
git reflog
git checkout -b recovered abc1234
```

## Tags

```bash
# List tags
git tag
git tag -l "v1.*"

# Create tag
git tag v1.0.0
git tag -a v1.0.0 -m "Release 1.0.0"   # annotated

# Tag specific commit
git tag v1.0.0 abc1234

# Push tags
git push origin v1.0.0
git push origin --tags

# Delete tag
git tag -d v1.0.0
git push origin --delete v1.0.0
```

## Clean

```bash
# Preview what would be removed
git clean -n

# Remove untracked files
git clean -f

# Remove untracked files and directories
git clean -fd

# Remove ignored files too
git clean -fdx
```

## Useful Patterns

```bash
# See what changed on a branch vs main
git log main..feature --oneline
git diff main...feature

# Find which commit introduced a bug
git bisect start
git bisect bad                 # current is broken
git bisect good v1.0.0         # this was fine
# git tests each commit, you mark good/bad
git bisect reset               # done

# Squash last N commits
git reset --soft HEAD~3
git commit -m "combined message"

# Create patch files
git format-patch main..feature
git am *.patch                 # apply patches

# Worktrees (multiple checkouts)
git worktree add ../hotfix main
git worktree list
git worktree remove ../hotfix

# Partial clone (large repos)
git clone --filter=blob:none https://github.com/user/repo.git
```
