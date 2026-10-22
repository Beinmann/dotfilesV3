#!/usr/bin/env bash
# Jump to the i3 workspace of a running devbox.
#
# bash_in_dev_container.sh (DevBox repo) moves its terminal to workspace
# "dev:<name>"; i3 drops a workspace once its last window closes, so the
# workspaces with that prefix are exactly the running devboxes.
#
# Each row is "path:name  title", taken from the DevBox registry (see
# bash_in_dev_container.sh, devbox-mark) for the devboxes open right now, so
# there is more to search for; boxes without a registry line show their name.
#
# Bound to a hotkey: checks i3 and the list, then opens a small floating
# tilix (see the devbox_switcher rule in the i3 config) running this script
# again with --pick, which shows the fzf list and switches.
set -euo pipefail

prefix="dev:"
switch="$(dirname "$0")/i3_switch_workspace.sh"
registry="${XDG_STATE_HOME:-$HOME/.local/state}/devbox/registry.tsv"

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

# Rows "name<TAB>display" for the running devboxes. A later registry line for
# a name wins; path "-" (devbox-mark) means no path to show.
picker_rows() {
  running_devboxes | awk -F'\t' -v home="$HOME" -v reg="$registry" '
    BEGIN {
      while ((getline line < reg) > 0) { split(line, f, "\t"); path[f[1]] = f[2]; title[f[1]] = f[3] }
    }
    {
      p = path[$1]
      if (home != "" && index(p, home "/") == 1) p = "~" substr(p, length(home) + 1)
      label = (p == "" || p == "-") ? $1 : p ":" $1
      if (title[$1] != "" && title[$1] != $1) label = label "  " title[$1]
      print $1 "\t" label
    }'
}

have_i3 || fail "i3 is not reachable (i3-msg -t get_version failed)."

if [[ "${1:-}" == "--pick" ]]; then
  rows=$(picker_rows)
  [[ -n "$rows" ]] || fail "No running devboxes."
  row=$(fzf --reverse --no-info --prompt 'devbox> ' \
    --delimiter '\t' --with-nth 2 <<< "$rows") || exit 0
  exec "$switch" "$prefix${row%%$'\t'*}"
fi

[[ -n "$(running_devboxes)" ]] || fail "No running devboxes."
exec tilix --new-process --class=devbox_switcher -t "devbox switcher" \
  -e "$(printf '%q --pick' "$0")"
