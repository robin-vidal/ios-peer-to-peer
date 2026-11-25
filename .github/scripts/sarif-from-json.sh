#!/bin/sh
set -eu

tool="$1"
report="$2"
sarif="$3"

if ! jq -e . "$report" >/dev/null 2>&1; then
  echo "$report is not JSON, $tool did not produce a report"
  exit 1
fi

case "$tool" in
  actionlint)
    jq '{
      version: "2.1.0",
      "$schema": "https://json.schemastore.org/sarif-2.1.0.json",
      runs: [{
        tool: {driver: {
          name: "actionlint",
          informationUri: "https://github.com/rhysd/actionlint",
          rules: ([.[].kind] | unique | map({id: ., shortDescription: {text: .}}))
        }},
        results: map({
          ruleId: .kind,
          level: "error",
          message: {text: .message},
          locations: [{physicalLocation: {
            artifactLocation: {uri: .filepath},
            region: {startLine: .line, startColumn: .column}
          }}]
        })
      }]
    }' "$report" > "$sarif"
    ;;
  shellcheck)
    jq '{
      version: "2.1.0",
      "$schema": "https://json.schemastore.org/sarif-2.1.0.json",
      runs: [{
        tool: {driver: {
          name: "shellcheck",
          informationUri: "https://www.shellcheck.net",
          rules: ([.comments[].code] | unique | map({
            id: "SC\(.)",
            shortDescription: {text: "SC\(.)"},
            helpUri: "https://www.shellcheck.net/wiki/SC\(.)"
          }))
        }},
        results: (.comments | map({
          ruleId: "SC\(.code)",
          level: ({error: "error", warning: "warning"}[.level] // "note"),
          message: {text: .message},
          locations: [{physicalLocation: {
            artifactLocation: {uri: .file},
            region: {startLine: .line, startColumn: .column, endLine: .endLine}
          }}]
        }))
      }]
    }' "$report" > "$sarif"
    ;;
  *)
    echo "no SARIF conversion for $tool"
    exit 1
    ;;
esac
