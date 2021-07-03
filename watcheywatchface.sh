#!/bin/zsh

set -euo pipefail

WATCH_REGEX='todo$'

echo "Watching ${$(readlink -f .)}"

if ! type inotifywait > /dev/null; then
  echo "inotifywait required, e.g. debian package inotify-tools" 1>&2
  exit 1
fi

if [[ "$(git rev-parse --show-toplevel 2>/dev/null)" != "$(pwd)" ]]; then
  echo "git not installed or working directory not a git root" 1>&2
  exit 1
fi

while IFS= read -r line; do
  # Avoid shenanigans with text editors which create a file and then write to it afterwards
  sleep .1

  FILENAME=$(echo $line | awk -F',' '{print $3}')
  if ! echo $FILENAME | grep $WATCH_REGEX > /dev/null; then
    # File doesn't match regex
    continue
  fi

  if git diff --exit-code --quiet $FILENAME && git ls-files --error-unmatch $FILENAME; then
    # File is already tracked and has no changes
    continue
  fi

  MESSAGE="watcheywatchface saw ${line}"
  echo $MESSAGE

  if ! git add $FILENAME; then
    echo "git add failed" 1>&2
    continue
  fi

  if ! git commit -m "$MESSAGE" --quiet; then
    echo "git commit failed" 1>&2
  fi

done < <(inotifywait --quiet --csv -e modify,create,delete . -m)
