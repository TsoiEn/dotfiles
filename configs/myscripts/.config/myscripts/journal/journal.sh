#!/usr/bin/env bash
# journal.sh — write a journal template into the current directory.
#
#   journal planning            -> YYYY-MM-DD-planning.md
#   journal technical [topic]   -> YYYY-MM-DD-<topic>.md
#   journal notes <topic>       -> <topic>.md
#   journal project [name]      -> PROJECT.md
#
# Never overwrites an existing file. Templates come from plan.txt.
set -euo pipefail

usage() { sed -n '2,8p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit "${1:-0}"; }

kind=${1:-}; shift || true
topic=${*:-}
date=$(date +%F)
slug=${topic// /-}

case $kind in
  planning)  file=$date-planning.md ;;
  technical) file=$date-${slug:-journal}.md ;;
  notes)     [[ -n $topic ]] || { echo "notes needs a topic" >&2; exit 1; }; file=$slug.md ;;
  project)   file=PROJECT.md ;;
  -h|--help|"") usage ;;
  *) echo "unknown template: $kind" >&2; usage 1 >&2 ;;
esac

[[ -e $file ]] && { echo "$file already exists" >&2; exit 1; }

template() {
  case $kind in
  planning) cat <<'T'
# Daily Planning — @DATE@

## Objectives

What do I want to accomplish today?

- [ ] Objective 1
- [ ] Objective 2
- [ ] Objective 3

## Tasks

### Personal

- [ ] Task

### Work

- [ ] Task

### Projects

- [ ] Task

### Learning

- [ ] Task

## Schedule

| Time  | Activity | Status  |
| ----- | -------- | ------- |
| 08:00 | Activity | Pending |
| 10:00 | Activity | Pending |
| 13:00 | Activity | Pending |

## Priorities

1. Highest priority:
2. Medium priority:
3. Low priority:

## End-of-Day Review

### Completed

-

### Incomplete

-

### Challenges

-

### Tomorrow

-
T
  ;;
  technical) cat <<'T'
# Technical Journal — @TOPIC@

**Date:** @DATE@
**Category:** Development / Linux / Cybersecurity / Networking
**Project:** Project Name
**Tags:** #technical #development

## 1. Context

What am I currently working on?

-

## 2. Objective

What am I trying to achieve?

-

## 3. Investigation

What did I research or investigate?

-

## 4. Implementation

What did I implement or configure?

### Commands / Code

```bash
# Commands used
```

```go
// Code snippets
```

## 5. Results

What happened after implementation?

- Expected result:
- Actual result:
- Status: Successful / Failed / Partial

## 6. Problems Encountered

| Problem | Cause | Solution |
| ------- | ----- | -------- |
|         |       |          |

## 7. Key Learnings

What did I learn from this activity?

-

## 8. References

- Documentation:
- Articles:
- Repositories:

## 9. Next Steps

- [ ] Next action
- [ ] Further investigation
T
  ;;
  notes) cat <<'T'
# @TOPIC@

**Category:** Programming / Linux / Networking / Security
**Created:** @DATE@
**Tags:** #reference #technical

## Overview

What is this?

-

## Definition

Explain the concept using precise terminology.

-

## How It Works

Explain the underlying mechanism.

1.
2.
3.

## Important Concepts

- Concept 1:
- Concept 2:
- Concept 3:

## Syntax / Commands

```bash
# Useful commands
```

## Code Examples

```go
// Example implementation
```

## Practical Applications

Where and when can this be used?

-

## Advantages and Limitations

### Advantages

-

### Limitations

-

## References

- Official documentation:
- Related resources:

## Related Notes

- [[Related Topic]]
T
  ;;
  project) cat <<'T'
# @TOPIC@

## 1. Overview

**Status:** Planning / In Progress / Completed
**Type:** Personal / Academic / Portfolio
**Primary Language:**

### Description

What is the project?

-

## 2. Problem Statement

What problem does this project solve?

-

## 3. Objectives

- [ ] Objective 1
- [ ] Objective 2
- [ ] Objective 3

## 4. Requirements

### Functional Requirements

- [ ] Requirement 1
- [ ] Requirement 2

### Non-Functional Requirements

- [ ] Performance
- [ ] Security
- [ ] Reliability

## 5. Technology Stack

| Component      | Technology | Purpose |
| -------------- | ---------- | ------- |
| Backend        |            |         |
| Frontend       |            |         |
| Database       |            |         |
| Infrastructure |            |         |

## 6. Architecture

Describe the system architecture.

-

## 7. Development Roadmap

### Phase 1 — Foundation

- [ ] Task

### Phase 2 — Core Development

- [ ] Task

### Phase 3 — Testing

- [ ] Task

### Phase 4 — Deployment

- [ ] Task

## 8. Technical Decisions

Record important implementation decisions.

-

## 9. Issues and Limitations

-

## 10. Future Improvements

-
T
  ;;
  esac
}

# shortcut: sed with '|' delimiter breaks if the topic contains '|' or '&'; fine for note titles.
template | sed -e "s|@DATE@|$date|g" -e "s|@TOPIC@|${topic:-Untitled}|g" > "$file"
echo "created $file"
