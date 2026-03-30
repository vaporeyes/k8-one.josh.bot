---
title: "jq"
description: "Quick reference for filtering, transforming, and querying JSON on the command line."
updatedDate: 2026-03-30
---

## Basics

```bash
# Pretty print
echo '{"a":1}' | jq .

# Read from file
jq . data.json

# Raw output (no quotes)
jq -r '.name' data.json

# Compact output
jq -c . data.json

# Exit status (for scripting)
jq -e '.enabled' data.json    # exit 1 if result is null/false
```

## Selecting Fields

```bash
# Single field
jq '.name'

# Nested field
jq '.user.address.city'

# Multiple fields
jq '{name: .name, age: .age}'

# Optional field (no error if missing)
jq '.maybe?'
jq '.user?.address?.city'
```

## Arrays

```bash
# All elements
jq '.[]'

# Specific index
jq '.[0]'
jq '.[-1]'                    # last element

# Slice
jq '.[2:5]'
jq '.[:3]'                    # first 3

# Length
jq '. | length'

# Array of a field from objects
jq '.[].name'
jq '[.[].name]'               # keep as array

# Flatten
jq 'flatten'
jq 'flatten(1)'               # one level
```

## Filtering

```bash
# Select by condition
jq '.[] | select(.age > 30)'
jq '.[] | select(.status == "active")'
jq '.[] | select(.name | startswith("J"))'
jq '.[] | select(.tags | contains(["prod"]))'

# Multiple conditions
jq '.[] | select(.age > 20 and .age < 40)'
jq '.[] | select(.role == "admin" or .role == "owner")'

# Null check
jq '.[] | select(.email != null)'
jq '.[] | select(.email // empty)'

# Has key
jq '.[] | select(has("email"))'

# Type check
jq '.[] | select(type == "string")'
```

## Transforming

```bash
# Map over array
jq 'map(.name)'
jq 'map({name, upper_name: (.name | ascii_upcase)})'
jq 'map(select(.active))'

# Add field
jq '.[] | . + {fullName: (.first + " " + .last)}'

# Remove field
jq 'del(.password)'
jq 'map(del(.internal_id))'

# Update field
jq '.name = "new name"'
jq '.count += 1'
jq '(.items[] | select(.id == 3)).status = "done"'

# To/from entries (object <-> key-value pairs)
jq 'to_entries'               # {a:1} -> [{key:"a",value:1}]
jq 'from_entries'             # reverse
jq 'to_entries | map(.value += 1) | from_entries'
jq 'with_entries(select(.value > 0))'
```

## String Operations

```bash
# Split / join
jq '.csv | split(",")'
jq '.tags | join(", ")'

# Test (regex match)
jq 'select(.name | test("^[Jj]"))'

# Capture (regex groups)
jq '.version | capture("(?<major>\\d+)\\.(?<minor>\\d+)")'

# Replace
jq '.name | gsub("old"; "new")'
jq '.path | sub("/api/v1"; "/api/v2")'

# String interpolation
jq '"Hello, \(.name)! Age: \(.age)"'

# Length, ltrimstr, rtrimstr
jq '.name | length'
jq '.path | ltrimstr("/")'
jq '.file | rtrimstr(".json")'

# ascii_downcase / ascii_upcase
jq '.name | ascii_downcase'
```

## Aggregation

```bash
# Count
jq '. | length'
jq '[.[] | select(.active)] | length'

# Sum
jq '[.[].price] | add'
jq 'map(.amount) | add'

# Min / max
jq 'min_by(.age)'
jq 'max_by(.score)'
jq '[.[].price] | min'

# Sort
jq 'sort_by(.name)'
jq 'sort_by(.date) | reverse'

# Unique
jq '[.[].category] | unique'
jq 'unique_by(.email)'

# Group
jq 'group_by(.category)'
jq 'group_by(.status) | map({status: .[0].status, count: length})'

# First / last
jq 'first(.[] | select(.active))'
jq 'last'
```

## Object Construction

```bash
# Build new object
jq '{id: .user_id, name: .user_name}'

# Collect into array
jq '[.[] | {name, status}]'

# Merge objects
jq '. * {"new_field": "value"}'
jq '.[0] * .[1]'                     # merge two objects

# Reduce
jq 'reduce .[] as $item (0; . + $item.count)'
jq 'reduce .[] as $item ({}; . + {($item.key): $item.value})'
```

## Variables and Functions

```bash
# Assign variable
jq '.users as $u | .orders | map(. + {user: ($u[] | select(.id == .user_id))})'

# Pass variable from shell
jq --arg name "$NAME" '.[] | select(.name == $name)'
jq --argjson count "$COUNT" '.limit = $count'

# Slurp (read all inputs as array)
jq -s '.' file1.json file2.json
jq -s 'map(.name) | unique' *.json

# Null input (construct from nothing)
jq -n '{name: "new", count: 0}'
jq -n --arg name "$NAME" '{name: $name}'

# Raw input (lines to JSON)
jq -R . <<< "hello"               # "hello"
jq -Rn '[inputs]' file.txt        # lines to array
```

## Conditionals

```bash
# if-then-else
jq 'if .age >= 18 then "adult" else "minor" end'

# Alternative operator (default)
jq '.name // "unknown"'
jq '(.config.timeout // 30)'

# try-catch
jq 'try .foo.bar catch "missing"'
jq '[.[] | try tonumber]'
```

## Useful Patterns

```bash
# kubectl + jq
kubectl get pods -o json | jq '.items[] | {name: .metadata.name, status: .status.phase}'
kubectl get nodes -o json | jq '.items[] | {name: .metadata.name, cpu: .status.capacity.cpu}'

# Terraform + jq
terraform show -json | jq '.values.root_module.resources[] | {type, name: .name, id: .values.id}'

# AWS CLI + jq
aws ec2 describe-instances | jq '.Reservations[].Instances[] | {id: .InstanceId, state: .State.Name, type: .InstanceType}'

# Flatten nested API response
jq '{items: [.data.results[] | {id, title: .name, active: (.status == "active")}]}'

# CSV-ish output
jq -r '.[] | [.name, .email, .role] | @csv'

# TSV output
jq -r '.[] | [.name, .email] | @tsv'

# Convert array of objects to lookup map
jq 'map({(.id | tostring): .}) | add'

# Diff two JSON files
diff <(jq -S . a.json) <(jq -S . b.json)
```
