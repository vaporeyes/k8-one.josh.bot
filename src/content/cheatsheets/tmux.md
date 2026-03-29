---
title: "tmux"
description: "Quick reference for tmux sessions, windows, panes, and configuration."
updatedDate: 2026-03-29
---

All commands use the default prefix `Ctrl-b` (shown as `C-b`). If you've rebound to `C-a`, substitute accordingly.

## Sessions

```bash
# New session
tmux new -s work

# Detach from session
# C-b d

# List sessions
tmux ls

# Attach to session
tmux attach -t work
tmux a -t work

# Kill session
tmux kill-session -t work

# Rename current session
# C-b $

# Switch sessions
# C-b s                  # interactive session picker
# C-b (                  # previous session
# C-b )                  # next session
```

## Windows

```bash
# New window
# C-b c

# Switch windows
# C-b 0-9                # by number
# C-b n                  # next
# C-b p                  # previous
# C-b l                  # last used
# C-b w                  # interactive window picker

# Rename window
# C-b ,

# Close window
# C-b &                  # or just `exit` in the shell

# Move window
# C-b .                  # move to a new index
```

## Panes

```bash
# Split pane
# C-b %                  # vertical split (left/right)
# C-b "                  # horizontal split (top/bottom)

# Navigate panes
# C-b arrow-keys         # move in direction
# C-b o                  # cycle through panes
# C-b q                  # show pane numbers, press number to jump

# Resize panes
# C-b C-arrow            # resize in direction (hold Ctrl)
# C-b z                  # toggle pane zoom (fullscreen)

# Close pane
# C-b x                  # or just `exit`

# Move panes
# C-b {                  # swap with previous
# C-b }                  # swap with next
# C-b !                  # break pane into its own window

# Convert between layouts
# C-b space              # cycle preset layouts
# C-b M-1                # even-horizontal
# C-b M-2                # even-vertical
# C-b M-3                # main-horizontal
# C-b M-4                # main-vertical
# C-b M-5                # tiled
```

## Copy Mode

```bash
# Enter copy mode
# C-b [

# In copy mode (vi keys if set):
# Space                  # start selection
# Enter                  # copy selection and exit
# q                      # exit copy mode
# /                      # search forward
# ?                      # search backward
# n                      # next match
# N                      # previous match

# Paste buffer
# C-b ]

# List buffers
tmux list-buffers

# Save buffer to file
tmux save-buffer -b 0 ~/buffer.txt
```

## Command Mode

```bash
# Enter command mode
# C-b :

# Useful commands
# :new-window -n logs "tail -f /var/log/syslog"
# :split-window -h
# :resize-pane -D 10
# :swap-window -t 0
# :setw synchronize-panes on       # type in all panes at once
# :setw synchronize-panes off
```

## CLI Commands

```bash
# Send keys to a session
tmux send-keys -t work "ls -la" Enter

# Capture pane output
tmux capture-pane -t work -p > output.txt

# Create a full layout from scratch
tmux new-session -d -s dev
tmux split-window -h -t dev
tmux split-window -v -t dev
tmux select-pane -t dev:0.0
tmux attach -t dev

# Resize from command line
tmux resize-pane -t 0 -x 80
tmux resize-pane -t 1 -y 20

# Display message
tmux display-message "hello"

# Wait for a channel (scripting)
tmux wait-for -S done
tmux wait-for done
```

## Configuration (~/.tmux.conf)

```bash
# Rebind prefix to C-a
unbind C-b
set -g prefix C-a
bind C-a send-prefix

# Start window/pane numbering at 1
set -g base-index 1
setw -g pane-base-index 1

# Renumber windows when one is closed
set -g renumber-windows on

# Enable mouse
set -g mouse on

# Vi copy mode
setw -g mode-keys vi

# Vi-style pane navigation
bind h select-pane -L
bind j select-pane -D
bind k select-pane -U
bind l select-pane -R

# Sane split bindings
bind | split-window -h -c "#{pane_current_path}"
bind - split-window -v -c "#{pane_current_path}"

# New windows in current path
bind c new-window -c "#{pane_current_path}"

# Faster escape (for vim)
set -sg escape-time 0

# Longer scrollback
set -g history-limit 50000

# 256 color + true color
set -g default-terminal "tmux-256color"
set -ag terminal-overrides ",xterm-256color:RGB"

# Status bar
set -g status-position top
set -g status-interval 5
set -g status-style 'bg=default,fg=white'

# Reload config
bind r source-file ~/.tmux.conf \; display "Reloaded"
```

## Useful Patterns

```bash
# Quick session from anywhere
tmux new -A -s main              # attach if exists, create if not

# IDE-style layout
tmux new-session -d -s ide -x 200 -y 50
tmux split-window -h -p 30 -t ide
tmux split-window -v -p 30 -t ide:0.1
tmux select-pane -t ide:0.0
tmux attach -t ide

# Save and restore (manual)
tmux list-windows -t work -F '#{window_layout}' > layout.txt

# Broadcast to all panes
tmux setw synchronize-panes on
# type commands... they go to every pane
tmux setw synchronize-panes off

# Pipe pane output to log
tmux pipe-pane -t 0 'cat >> ~/pane0.log'
tmux pipe-pane -t 0                        # stop piping
```

## Key Reference

| Key | Action |
|-----|--------|
| `C-b d` | Detach |
| `C-b c` | New window |
| `C-b ,` | Rename window |
| `C-b w` | Window picker |
| `C-b %` | Split vertical |
| `C-b "` | Split horizontal |
| `C-b z` | Zoom pane |
| `C-b x` | Kill pane |
| `C-b [` | Copy mode |
| `C-b ]` | Paste |
| `C-b :` | Command mode |
| `C-b ?` | List all bindings |
