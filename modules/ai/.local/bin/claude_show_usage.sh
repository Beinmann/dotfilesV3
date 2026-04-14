#!/bin/bash
#
# Show 5h + 7d Claude API usage limits with reset time
#
# Original script by vildanbina, extended by Beinmann

set -euo pipefail

CACHE="$HOME/.cache/cc-usage.txt"
LOCK="$HOME/.cache/cc-usage.lock"
CREDS="${CC_CREDENTIALS:-$HOME/.claude/.credentials.json}"
TTL="${CC_CACHE_TTL:-60}"

# Return cached if fresh
if [[ -f "$CACHE" ]]; then
    age=$(($(date +%s) - $(stat -c '%Y' "$CACHE" 2>/dev/null || echo 0)))
    [[ $age -lt $TTL ]] && cat "$CACHE" && exit 0
fi

# Rate limit API calls
if [[ -f "$LOCK" ]]; then
    age=$(($(date +%s) - $(stat -c '%Y' "$LOCK" 2>/dev/null || echo 0)))
    [[ $age -lt 30 ]] && { [[ -f "$CACHE" ]] && cat "$CACHE"; exit 0; }
fi
touch "$LOCK"

# Get token
[[ ! -f "$CREDS" ]] && echo "[No creds]" && exit 1
token=$(jq -r '.claudeAiOauth.accessToken // empty' "$CREDS" 2>/dev/null)
[[ -z "$token" ]] && echo "[Bad token]" && exit 1

# Fetch usage
resp=$(curl -s --max-time 5 \
    "https://api.anthropic.com/api/oauth/usage" \
    -H "Authorization: Bearer $token" \
    -H "anthropic-beta: oauth-2025-04-20" 2>/dev/null) || true

[[ -z "$resp" ]] && { [[ -f "$CACHE" ]] && cat "$CACHE"; echo "[Timeout]"; exit 1; }

session=$(echo "$resp" | jq -r '.five_hour.utilization // empty' 2>/dev/null)
weekly=$(echo "$resp"  | jq -r '.seven_day.utilization // empty'  2>/dev/null)
resets_at=$(echo "$resp" | jq -r '.five_hour.resets_at // empty'  2>/dev/null)

[[ -z "$session" || -z "$weekly" ]] && { [[ -f "$CACHE" ]] && cat "$CACHE"; echo "[Error]"; exit 1; }

# Format reset time as "in Xh Ym" or "in Xm"
reset_str=""
if [[ -n "$resets_at" ]]; then
    reset_epoch=$(date -d "$resets_at" +%s 2>/dev/null || true)
    if [[ -n "$reset_epoch" ]]; then
        diff=$(( reset_epoch - $(date +%s) ))
        if [[ $diff -gt 0 ]]; then
            h=$(( diff / 3600 ))
            m=$(( (diff % 3600) / 60 ))
            if [[ $h -gt 0 ]]; then
                reset_str=" (resets in ${h}h ${m}m)"
            else
                reset_str=" (resets in ${m}m)"
            fi
        else
            reset_str=" (resetting soon)"
        fi
    fi
fi

echo "5h: ${session}%${reset_str} | 7d: ${weekly}%" | tee "$CACHE"
