#!/usr/bin/env bash
# Jump to the i3 workspace of a running devbox.
#
# bash_in_dev_container.sh (DevBox repo) moves its terminal to workspace
# "dev:<name>"; i3 drops a workspace once its last window closes, so the
# workspaces with that prefix are exactly the running devboxes.
#
# Bound to a hotkey: checks i3 and the list, then opens a small floating
# tilix (see the devbox_switcher rule in the i3 config) running this script
# again with --pick, which shows the fzf list and switches.
set -euo pipefail

prefix="dev:"
switch="$(dirname "$0")/i3_switch_workspace.sh"

fail() {
  echo "devbox_switcher: $1" >&2
  notify-send "Devbox switcher" "$1" 2>/dev/null || true
  exit 1
}

have_i3() { command -v i3-msg >/dev/null 2>&1 && i3-msg -t get_version >/dev/null 2>&1; }

running_devboxes() {
  i3-msg -t get_workspaces | jq -r --arg p "$prefix" \
    '.[].name | select(startswith($p)) | .[($p | length):]' | sort
}

have_i3 || fail "i3 is not reachable (i3-msg -t get_version failed)."

if [[ "${1:-}" == "--pick" ]]; then
  list=$(running_devboxes)
  [[ -n "$list" ]] || fail "No running devboxes."
  choice=$(fzf --reverse --no-info --prompt 'devbox> ' <<< "$list") || exit 0
  exec "$switch" "$prefix$choice"
fi

[[ -n "$(running_devboxes)" ]] || fail "No running devboxes."
exec tilix --new-process --class=devbox_switcher -t "devbox switcher" \
  -e "$(printf '%q --pick' "$0")"
