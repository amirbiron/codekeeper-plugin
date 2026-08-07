# CodeKeeper Memory — SessionStart hook
#
# Prints the agent primer to stdout. Claude Code injects a SessionStart hook's
# stdout straight into the session context, so whatever this prints is loaded
# before the first user message — no CLI to install, and no dependence on the
# model deciding to call a tool.
#
# Deliberately silent on every failure path. A memory primer must never be the
# reason a session refuses to start: no token, no network, slow server, bad
# JSON — all of them exit 0 with nothing printed, and the session proceeds
# exactly as it would without the plugin.
#
# MIT. Structure adapted from Vertiso/memory-claude (MIT, © 2026 Vertiso
# Corporation); the fetch-and-print approach here is not theirs.

URL="${CODEKEEPER_PRIMER_URL:-https://code-keeper-webapp.onrender.com/api/agent/primer}"

# No token means the endpoint would 401 anyway. Leave quietly.
[ -n "${CODEKEEPER_PAT:-}" ] || exit 0
command -v curl >/dev/null 2>&1 || exit 0

# --max-time is the load-bearing flag: hooks.json allows 10s, so cap the
# request below that. Render free tier cold-starts, and a sleeping server must
# cost the session a few seconds, never a hang.
body=$(
  curl -fsS --max-time 6 \
    -H "Authorization: Bearer ${CODEKEEPER_PAT}" \
    -H "Accept: text/plain" \
    "$URL" 2>/dev/null
) || exit 0

[ -n "$body" ] || exit 0

printf '%s\n' "$body"
exit 0
