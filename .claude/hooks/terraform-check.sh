#!/bin/bash
input=$(cat)
cwd=$(echo "$input" | jq -r '.cwd')
transcript_path=$(echo "$input" | jq -r '.transcript_path')
failed=0

if ! command -v terraform &>/dev/null; then
  exit 0
fi

if [ ! -f "$transcript_path" ]; then
  exit 0
fi

# Collect directories of edited .tf/.tfvars files from the transcript
dirs=$(jq -r '
  select(.type == "assistant") | .message.content[]?
  | select(.type == "tool_use" and (.name == "Edit" or .name == "Write" or .name == "MultiEdit"))
  | .input.file_path
  | select(. != null and (endswith(".tf") or endswith(".tfvars")))
' "$transcript_path" 2>/dev/null | xargs -I{} dirname {} | sort -u)

if [ -z "$dirs" ]; then
  exit 0
fi

while IFS= read -r dir; do
  if [ ! -d "$dir" ]; then
    continue
  fi

  terraform -chdir="$dir" fmt >/dev/null 2>&1
  if ! terraform -chdir="$dir" fmt -check >/dev/null 2>&1; then
    echo "terraform fmt failed to resolve formatting issues in $dir"
    failed=1
  fi

  if ! terraform -chdir="$dir" init -backend=false >/dev/null 2>&1; then
    echo "terraform init failed in $dir"
    failed=1
    continue
  fi

  output=$(terraform -chdir="$dir" validate 2>&1)
  if [ $? -ne 0 ]; then
    echo "terraform validate failed in $dir:"
    echo "$output"
    failed=1
  fi
done <<< "$dirs"

exit $failed
