#!/bin/sh
set -eu

report="$1"
skipped=$(jq -n '[inputs | select(.type == "testDone" and .skipped == true and .hidden != true)] | length' "$report")

if [ "$skipped" -ne 0 ]; then
  echo "$skipped test(s) were skipped in $report, every test must run here"
  exit 1
fi
