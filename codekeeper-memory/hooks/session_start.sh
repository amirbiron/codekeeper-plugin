# CodeKeeper Memory — SessionStart hook
#
# Fetches the agent primer and prints it. Claude Code injects a SessionStart
# hook's stdout straight into the session context, so whatever lands on stdout
# is loaded before the first user message — no CLI to install, and no
# dependence on the model deciding to call a tool.
#
# The split that matters: the primer goes to STDOUT, diagnostics go to STDERR.
# Stdout is context the agent reads; stderr is a message to the human. Nothing
# but the primer may ever reach stdout, or the agent starts reading our error
# text as if it were instructions from Amir.
#
# Silence is reserved for exactly one case: HTTP 204, meaning the account has
# no agent instructions. That is a legitimate empty state, not a fault. Every
# other failure — no token, no URL, 4xx, 5xx, timeout — says one line on
# stderr. An always-silent hook is indistinguishable from a working one, which
# is how a broken URL survives for months unnoticed.
#
# The session always starts. Every path here exits 0.
#
# MIT. Plugin structure adapted from Vertiso/memory-claude (MIT, © 2026
# Vertiso Corporation); the fetch-and-print approach and this diagnostic
# handling are not theirs.

note() { printf 'codekeeper-memory: %s\n' "$1" >&2; }

# No default host on purpose. The primer is served by the MCP service, which is
# a different Render service from the webapp — a plausible-looking default that
# points at the wrong host 404s forever, and the whole point of this rewrite is
# that a misconfiguration must be audible.
URL="${CODEKEEPER_PRIMER_URL:-}"

if [ -z "$URL" ]; then
  note "CODEKEEPER_PRIMER_URL is not set — primer not loaded."
  exit 0
fi

if [ -z "${CODEKEEPER_PAT:-}" ]; then
  note "CODEKEEPER_PAT is not set — primer not loaded."
  exit 0
fi

if ! command -v curl >/dev/null 2>&1; then
  note "curl not found on PATH — primer not loaded."
  exit 0
fi

body_file=$(mktemp 2>/dev/null) || { note "could not create a temp file."; exit 0; }

# No -f here: we want the status code and the body, not curl's pass/fail.
# --max-time 6 is load-bearing — hooks.json allows 10s, and Render's free tier
# cold-starts. A sleeping server must cost a few seconds, never a hang.
code=$(
  curl -sS -o "$body_file" -w '%{http_code}' --max-time 6 \
    -H "Authorization: Bearer ${CODEKEEPER_PAT}" \
    -H "Accept: text/plain" \
    "$URL" 2>/dev/null
) || code="000"

case "$code" in
  200)
    if [ -s "$body_file" ]; then
      cat "$body_file"
    else
      note "server returned 200 with an empty body — expected 204 for no instructions."
    fi
    ;;
  204)
    # No agent instructions configured. Correct, expected, and silent.
    :
    ;;
  401|403)
    note "authentication rejected (HTTP $code) — check CODEKEEPER_PAT."
    ;;
  404)
    note "primer endpoint not found (HTTP 404) at $URL — check CODEKEEPER_PRIMER_URL points at the MCP service, not the webapp."
    ;;
  000)
    note "could not reach $URL (timeout or network error)."
    ;;
  *)
    note "unexpected response (HTTP $code) from $URL."
    ;;
esac

rm -f "$body_file"
exit 0
