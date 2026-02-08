#!/bin/bash
input=$(cat)
file_path=$(echo "$input" | jq -r '.tool_input.file_path // empty')

if [ -z "$file_path" ]; then
  exit 0
fi

case "$file_path" in
  *.tf) ;;
  *) exit 0 ;;
esac

output=$(terraform fmt -check -diff "$file_path" 2>&1)
if [ $? -ne 0 ]; then
  terraform fmt "$file_path" >/dev/null 2>&1
  echo '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"terraform fmt applied to '"$file_path"'"}}'
fi
