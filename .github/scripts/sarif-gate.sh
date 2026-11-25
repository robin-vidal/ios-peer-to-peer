#!/bin/sh
set -eu

sarif="$1"

if [ ! -s "$sarif" ]; then
  echo "$sarif is missing or empty, the tool did not produce a report"
  exit 1
fi

if ! jq -e '
  .version == "2.1.0"
  and (.runs | type == "array" and length > 0)
  and all(.runs[]; (.tool.driver.name // "") != "")
' "$sarif" >/dev/null; then
  echo "$sarif is not a SARIF 2.1.0 log with at least one named tool run"
  exit 1
fi

normalised="$sarif.normalised"

jq '
  def score($tags; $levels):
    if any($tags[]; . == "HIGH") then "8.0"
    elif any($tags[]; . == "MEDIUM") then "5.5"
    elif any($tags[]; . == "LOW") then "3.0"
    elif any($levels[]; . == "error") then "8.0"
    elif any($levels[]; . == "warning") then "5.0"
    elif any($levels[]; . == "note") then "2.0"
    else "5.0"
    end;

  .runs |= map(
    ([.results // [] | .[] | select(.ruleId != null) | {id: .ruleId, level: (.level // "warning")}]
      | group_by(.id)
      | map({key: .[0].id, value: map(.level)})
      | from_entries) as $levels
    | (.tool.driver.rules // []) as $rules
    | ($rules | map(.id)) as $known
    | .tool.driver.rules = $rules + [
        $levels | keys[] | select(. as $id | any($known[]; . == $id) | not) | {id: .}
      ]
    | .tool.driver.rules |= map(
        if (.properties["security-severity"] // null) != null then .
        else
          .properties["security-severity"] = score(.properties.tags // []; $levels[.id] // [])
          | .properties.tags = ((.properties.tags // []) + ["security"] | unique)
        end
      )
  )
' "$sarif" > "$normalised"
mv "$normalised" "$sarif"

results=$(jq '[.runs[].results // [] | length] | add' "$sarif")
echo "$sarif holds $results result(s), every rule carries a security severity"
