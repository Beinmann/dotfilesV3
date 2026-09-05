#!/bin/bash
#
# Emit a terminal bell into the invoking tmux pane so that tmux's
# bell-monitoring flags the window when Claude finishes responding or
# is waiting on the user (permission prompt / idle).
#
# Wired up as the Stop and Notification hooks in .claude/settings.json.

if [ -n "$TMUX" ]; then
    printf '\a'
fi
exit 0
