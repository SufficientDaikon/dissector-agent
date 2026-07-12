#!/usr/bin/env bash
# write-guard.sh — Dissector plugin PreToolUse hook for Write|Edit.
#
# Dissector's specialist agents must only ever write inside the dissection
# output folder (a "*-dissection/" directory). This hook is a harness-level
# backstop against a prompt-injection payload in an analyzed codebase steering
# an agent into writing elsewhere (e.g. ~/.ssh, source files, CI configs).
#
# Contract (Claude Code hooks):
#   - Tool call JSON arrives on stdin; .tool_input.file_path is the target.
#   - We ALLOW writes whose canonical path is inside a "*-dissection" folder by
#     emitting an explicit PreToolUse permissionDecision of "allow". A bare
#     `exit 0` is NOT sufficient under plugin load: the agents' acceptEdits
#     permission mode is ignored for plugin hooks, and a no-output PreToolUse
#     hook DEFERS to the session permission mode rather than approving — so
#     every specialist KB write would otherwise prompt (interactive) or
#     auto-deny (`claude -p`). The explicit "allow" is what unblocks the write.
#   - Otherwise we emit a PreToolUse permissionDecision of "ask" so the human
#     is prompted rather than silently blocked (the main-session user's own
#     edits outside a dissection folder should not be hard-denied by a plugin).
#   - Defensive: if jq is missing or input is unparseable, exit 0 (pass-through)
#     so we never break the user's session.

set -u

# jq missing -> pass through, do not block the session.
if ! command -v jq >/dev/null 2>&1; then
  exit 0
fi

input="$(cat)"

file_path="$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null)"

# No file_path to evaluate -> nothing to guard, pass through.
if [ -z "$file_path" ]; then
  exit 0
fi

# Canonicalize. The target may not exist yet (a new file), so canonicalize the
# parent directory and re-append the basename. If NO canonicalization tool is
# available, leave $canon empty: we must NEVER make the security decision from a
# raw, un-normalized path (a raw "<x>-dissection/../../etc/passwd" would slip
# through the "*-dissection/*" glob). An empty $canon forces the "ask" branch.
canon=""
dir="$(dirname "$file_path")"
base="$(basename "$file_path")"
if command -v realpath >/dev/null 2>&1; then
  rdir="$(realpath -m "$dir" 2>/dev/null || realpath "$dir" 2>/dev/null || true)"
  [ -n "$rdir" ] && canon="$rdir/$base"
elif command -v readlink >/dev/null 2>&1 && readlink -f / >/dev/null 2>&1; then
  rdir="$(readlink -f "$dir" 2>/dev/null || true)"
  [ -n "$rdir" ] && canon="$rdir/$base"
fi

# Path-traversal backstop: stock older BSD realpath has no -m and cannot
# normalize a not-yet-existing path, so a ".." segment can survive. If a ".."
# path segment remains in $canon, do NOT trust it for an allow decision — drop
# to empty so the case-match below cannot take an allow branch.
case "/$canon/" in
  *"/../"*) canon="" ;;
esac

# Decide. Only a fully canonical path with no surviving ".." reaches here with a
# non-empty $canon.
allow=""
if [ -n "$canon" ]; then
  # ALLOW if any path segment is a "*-dissection" folder (canonical path
  # contains "-dissection/") ...
  case "$canon" in
    *-dissection/*) allow="inside dissection output folder" ;;
  esac
  # ... or the file sits directly inside one (immediate parent ends -dissection).
  if [ -z "$allow" ]; then
    parent_name="$(basename "$(dirname "$canon")")"
    case "$parent_name" in
      *-dissection) allow="inside dissection output folder" ;;
    esac
  fi
fi

if [ -n "$allow" ]; then
  jq -cn --arg r "$allow" \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"allow",permissionDecisionReason:$r}}'
  exit 0
fi

# Everything else -> ask the user. Build the JSON with jq so paths containing a
# double-quote or backslash cannot produce invalid JSON (a hand-rolled printf
# would fail open exactly on adversarial paths).
target="${canon:-$file_path}"
reason="Dissector agents write only inside the dissection output folder; this write targets ${target}"
jq -cn --arg r "$reason" \
  '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"ask",permissionDecisionReason:$r}}'
exit 0
