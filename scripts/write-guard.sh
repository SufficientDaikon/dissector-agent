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
#   - We ALLOW (exit 0, no output) writes whose canonical path is inside a
#     "*-dissection" folder.
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
# parent directory and re-append the basename. Fall back to the raw path if no
# realpath tool is available.
canon=""
dir="$(dirname "$file_path")"
base="$(basename "$file_path")"
if command -v realpath >/dev/null 2>&1; then
  rdir="$(realpath -m "$dir" 2>/dev/null || realpath "$dir" 2>/dev/null || echo "$dir")"
  canon="$rdir/$base"
elif command -v readlink >/dev/null 2>&1 && readlink -f / >/dev/null 2>&1; then
  rdir="$(readlink -f "$dir" 2>/dev/null || echo "$dir")"
  canon="$rdir/$base"
else
  canon="$file_path"
fi

# ALLOW if any path segment is a "*-dissection" folder (i.e. the canonical path
# contains "-dissection/") or the file itself sits directly in one.
case "$canon" in
  *-dissection/*)
    exit 0
    ;;
esac
# Also allow when the immediate parent directory name ends in -dissection
# (write of a file directly inside the output folder root).
parent_name="$(basename "$(dirname "$canon")")"
case "$parent_name" in
  *-dissection)
    exit 0
    ;;
esac

# Everything else -> ask the user.
reason="Dissector agents write only inside the dissection output folder; this write targets ${canon}"
printf '%s\n' "{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"permissionDecision\":\"ask\",\"permissionDecisionReason\":\"$(printf '%s' "$reason" | sed 's/\\\\/\\\\\\\\/g; s/\"/\\\\\"/g')\"}}"
exit 0
