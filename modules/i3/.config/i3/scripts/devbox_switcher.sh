#!/usr/bin/env bash
# Jump to the i3 workspace of a running devbox or named workspace.
#
# Named workspaces ("ws:<name>", registry named_workspaces.tsv next to the
# devbox registry, same columns) are the general form: any window put there
# with ws-mark --ws, e.g. a browser window to keep around.
#
# bash_in_dev_container.sh (DevBox repo) moves its terminal to workspace
# "dev:<name>"; i3 drops a workspace once its last window closes, so the
# workspaces with that prefix are exactly the running devboxes.
#
# Each row is "path:name  title", taken from the DevBox registry (see
# bash_in_dev_container.sh, ws-mark) for the devboxes open right now, so
# there is more to search for; boxes without a registry line show their name.
#
# Bound to a hotkey: checks i3 and the list, then opens a small floating
# tilix (see the devbox_switcher rule in the i3 config) running this script
# again with --pick, which shows the fzf list and switches.
set -euo pipefail

prefix="dev:"
ws_prefix="ws:"
switch="$(dirname "$0")/i3_switch_workspace.sh"
registry="${XDG_STATE_HOME:-$HOME/.local/state}/devbox/registry.tsv"
ws_registry="${XDG_STATE_HOME:-$HOME/.local/state}/devbox/named_workspaces.tsv"

fail() {
  echo "devbox_switcher: $1" >&2
  notify-send "Devbox switcher" "$1" 2>/dev/null || true
  exit 1
}

have_i3() { command -v i3-msg >/dev/null 2>&1 && i3-msg -t get_version >/dev/null 2>&1; }

# Full workspace names of the open devboxes ("dev:<name>") and then of the
# open named workspaces ("ws:<name>", see ws-mark --ws).
running_workspaces() {
  local names p
  names=$(i3-msg -t get_workspaces | jq -r '.[].name')
  for p in "$prefix" "$ws_prefix"; do
    awk -v p="$p" 'index($0, p) == 1 && length($0) > length(p)' <<< "$names" | sort
  done
}

# Rows "workspace<TAB>display" for the open devboxes and named workspaces. A
# later registry line for a name wins; path "-" (ws-mark) means no path.
picker_rows() {
  running_workspaces | awk -F'\t' -v home="$HOME" -v reg="$registry" -v wsreg="$ws_registry" \
      -v dp="$prefix" -v wp="$ws_prefix" '
    function load(file, tag,   line, f) {
      while ((getline line < file) > 0) { split(line, f, "\t"); path[tag f[1]] = f[2]; title[tag f[1]] = f[3] }
    }
    BEGIN { load(reg, "d:"); load(wsreg, "w:") }
    {
      if (index($0, dp) == 1) { tag = "d:"; name = substr($0, length(dp) + 1) }
      else { tag = "w:"; name = substr($0, length(wp) + 1) }
      p = path[tag name]
      if (home != "" && index(p, home "/") == 1) p = "~" substr(p, length(home) + 1)
      label = (p == "" || p == "-") ? name : p ":" name
      if (title[tag name] != "" && title[tag name] != name) label = label "  " title[tag name]
      print $0 "\t" label
    }'
}

have_i3 || fail "i3 is not reachable (i3-msg -t get_version failed)."

if [[ "${1:-}" == "--pick" ]]; then
  rows=$(picker_rows)
  [[ -n "$rows" ]] || fail "No running devboxes or named workspaces."
  row=$(fzf --reverse --no-info --prompt 'devbox> ' \
    --delimiter '\t' --with-nth 2 <<< "$rows") || exit 0
  exec "$switch" "${row%%$'\t'*}"
fi

[[ -n "$(running_workspaces)" ]] || fail "No running devboxes or named workspaces."
exec tilix --new-process --class=devbox_switcher -t "devbox switcher" \
  -e "$(printf '%q --pick' "$0")"
