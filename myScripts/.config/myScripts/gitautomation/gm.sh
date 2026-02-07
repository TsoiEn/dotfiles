#!/usr/bin/env bash

set -e

# Get repository status
STATUS=$(git status --porcelain)

if [ -z "$STATUS" ]; then
  echo "No changes to commit."
  exit 0
fi

# Collect files
NEW_FILES=$(echo "$STATUS" | awk '/^\?\?/ {print $2}')
MOD_FILES=$(echo "$STATUS" | awk '/^ M|^M / {print $2}')
DEL_FILES=$(echo "$STATUS" | awk '/^ D|^D / {print $2}')

# Build commit title
TITLE_PARTS=()
[ -n "$NEW_FILES" ] && TITLE_PARTS+=("add")
[ -n "$MOD_FILES" ] && TITLE_PARTS+=("update")
[ -n "$DEL_FILES" ] && TITLE_PARTS+=("remove")

COMMIT_TITLE=$(IFS="/"; echo "${TITLE_PARTS[*]} files")

# Build commit description
DESCRIPTION=""

if [ -n "$NEW_FILES" ]; then
  DESCRIPTION+="New files:\n"
  DESCRIPTION+=$(echo "$NEW_FILES" | sed 's/^/  - /')
  DESCRIPTION+="\n\n"
fi

if [ -n "$MOD_FILES" ]; then
  DESCRIPTION+="Modified files:\n"
  DESCRIPTION+=$(echo "$MOD_FILES" | sed 's/^/  - /')
  DESCRIPTION+="\n\n"
fi

if [ -n "$DEL_FILES" ]; then
  DESCRIPTION+="Deleted files:\n"
  DESCRIPTION+=$(echo "$DEL_FILES" | sed 's/^/  - /')
  DESCRIPTION+="\n\n"
fi

# Commit
git add .
git commit -m "$COMMIT_TITLE" -m "$(echo -e "$DESCRIPTION")"
