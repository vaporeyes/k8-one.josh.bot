---
title: "Fish Shell"
description: "Quick reference for fish shell commands, syntax, and configuration."
updatedDate: 2026-03-29
---

## Variables

```fish
# Set a variable
set myvar "hello"

# Export to child processes
set -x MY_ENV_VAR "value"

# Erase a variable
set -e myvar

# List (array) variable
set mylist one two three
echo $mylist[1]       # "one" (1-indexed)
echo $mylist[2..3]    # "two three"

# Universal variables (persist across sessions)
set -U fish_greeting ""
```

## String Manipulation

```fish
# String replace
string replace "old" "new" "old string"

# Regex match
string match -r '\d+' "file42.txt"   # "42"

# Split
string split "," "a,b,c"

# Trim whitespace
string trim "  hello  "

# Upper/lower
string upper "hello"
string lower "HELLO"

# Substring
string sub -s 1 -l 3 "hello"   # "hel"
```

## Control Flow

```fish
# If/else
if test -f myfile.txt
    echo "exists"
else if test -d mydir
    echo "is a directory"
else
    echo "not found"
end

# Switch
switch $argv[1]
    case start
        echo "starting"
    case stop
        echo "stopping"
    case '*'
        echo "unknown"
end

# For loop
for f in *.txt
    echo $f
end

# While loop
while read -l line
    echo $line
end < input.txt
```

## Functions

```fish
# Define a function
function greet
    echo "hello, $argv[1]"
end

# With description (shows in `functions` output)
function ll --description "Long list with human sizes"
    ls -lah $argv
end

# Event handler
function on_exit --on-event fish_exit
    echo "bye"
end

# Save function permanently
funcsave greet
```

## Abbreviations

```fish
# Add an abbreviation (expands inline as you type)
abbr -a g git
abbr -a gc "git commit"
abbr -a gp "git push"
abbr -a k kubectl

# List abbreviations
abbr

# Remove
abbr -e g
```

## Command Substitution and Piping

```fish
# Command substitution (no backticks)
set files (ls)
set count (wc -l < myfile.txt)

# Pipe
cat file.txt | sort | uniq -c | sort -rn

# Process substitution
diff (sort a.txt | psub) (sort b.txt | psub)

# Status of last command
echo $status

# Redirect stderr
command 2>/dev/null
command 2>&1
```

## Job Control

```fish
# Background a process
long_command &

# List jobs
jobs

# Bring to foreground
fg %1

# Disown (detach from shell)
disown %1
```

## Path Management

```fish
# Add to PATH (prepend)
fish_add_path ~/bin

# Add to PATH (append)
fish_add_path -a /opt/tools/bin

# View current PATH
echo $PATH | string split " "
# or
printf '%s\n' $PATH
```

## Completions

```fish
# Add a completion
complete -c mycommand -s h -l help -d "Show help"
complete -c mycommand -s v -l verbose -d "Verbose output"

# File-type restricted
complete -c mycommand -s f -l file -r -F  # require file argument

# Subcommand completions
complete -c mycommand -n "__fish_use_subcommand" -a "start stop status"
```

## Key Bindings

```fish
# List all bindings
bind

# Custom binding
bind \cf forward-char
bind \cb backward-char

# Vi mode
fish_vi_key_bindings

# Back to default (emacs)
fish_default_key_bindings
```

## Useful Builtins

```fish
# Test (conditions)
test -f file.txt     # file exists
test -d mydir        # directory exists
test -z "$var"       # string is empty
test -n "$var"       # string is non-empty
test $a -eq $b       # numeric equal

# Math
math "2 + 2"
math "ceil(3.2)"
set pct (math "$part / $total * 100")

# Type checking
type -t ls           # "file", "builtin", "function"

# Read user input
read -P "Name: " name

# Random
random 1 100

# Source a file
source ~/.config/fish/local.fish
```

## Configuration Files

```
~/.config/fish/config.fish       # main config (like .bashrc)
~/.config/fish/conf.d/*.fish     # auto-loaded config snippets
~/.config/fish/functions/        # auto-loaded function files
~/.config/fish/completions/      # custom completions
```

## Useful Patterns

```fish
# Default argument value
set -q argv[1]; or set argv[1] "default"

# Check if command exists
if command -q docker
    echo "docker is installed"
end

# Iterate with index
for i in (seq (count $mylist))
    echo "$i: $mylist[$i]"
end

# Multiline command (no backslash needed after pipe/and/or)
command1 |
    command2 |
    command3

# Inline conditional
test -f config.yml; and source_config; or use_defaults
```
