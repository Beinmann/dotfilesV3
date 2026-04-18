#!/usr/bin/env bash
set -euo pipefail

file="/tmp/i3_prev_workspace"

if [[ ! -r "$file" ]]; then
  notify-send "Error:" "$file not found or not readable." >&2
  exit 1
fi
prev_workspace=$(< "$file")
if [[ -z "$prev_workspace" ]]; then
  notify-send "Error:" "workspace file is empty." >&2
  exit 1
fi

script="$HOME/.config/i3/scripts/i3_switch_workspace.sh"
if [[ ! -x "$script" ]]; then
  notify-send "Error:" "$script not found or not executable." >&2
  exit 1
fi

"$script" "$prev_workspace"
