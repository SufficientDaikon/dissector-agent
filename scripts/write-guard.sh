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
#   - ACTIVE-RUN GATE: plugin hooks load at user scope and fire on every
#     Write|Edit in every session — but this guard is only meaningful WHILE a
#     dissection is running. The /dissect orchestrator marks a live run with
#     OUTPUT_PATH/.dissect-lock (created in Stage 0, removed in Stage 4, stale
#     after 2h — same window Stage 0 uses). If no fresh lock exists under the
#     session directory AND the write target is not itself inside a
#     "*-dissection" folder, we emit NOTHING and exit 0: a silent PreToolUse
#     hook defers to the user's own permission settings, so ordinary editing
#     everywhere else is never prompted by this plugin.
#   - When a run IS active: we ALLOW writes whose canonical path is inside a
#     "*-dissection" folder by emitting an explicit PreToolUse
#     permissionDecision of "allow". A bare `exit 0` is NOT sufficient under
#     plugin load: the agents' acceptEdits permission mode is ignored for
#     plugin hooks, and a no-output PreToolUse hook DEFERS to the session
#     permission mode rather than approving — so every specialist KB write
#     would otherwise prompt (interactive) or auto-deny (`claude -p`). The
#     explicit "allow" is what unblocks the write.
#   - Any other mid-run write gets a permissionDecision of "ask" so the human
#     is prompted rather than silently blocked — this is the prompt-injection
#     backstop, scoped to the only window where it matters.
#   - Defensive: if jq is missing or input is unparseable, exit 0 (pass-through)
#     so we never break the user's session.

set -u

# Interactive-shell / no-stdin guard. Claude Code always PIPES the tool-call JSON
# to this hook's stdin, so in normal operation stdin is a pipe. If stdin is an
# interactive terminal instead (e.g. on Windows, Git Bash launching the hook as
# `bash --login -i`, which pops a console and leaves the `cat` below blocking on
# the keyboard forever), there is no JSON to guard — pass through immediately so
# we never hang a visible window. Harmless in the normal path: a pipe is not a tty.
if [ -t 0 ]; then
  exit 0
fi

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

# ---- Active-run gate -------------------------------------------------------
# Only guard while a dissection is actually in progress. Signal: a fresh
# .dissect-lock directly inside a "*-dissection" child of the session
# directory (the orchestrator always creates OUTPUT_FOLDER in the session
# CWD, so depth 2 is exact). Session dir: the hook input's .cwd, falling back
# to $CLAUDE_PROJECT_DIR, then $PWD.
session_dir="$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)"
if [ -z "$session_dir" ] || [ ! -d "$session_dir" ]; then
  session_dir="${CLAUDE_PROJECT_DIR:-$PWD}"
fi

run_active=""
if [ -d "$session_dir" ]; then
  lock_hit="$(find "$session_dir" -maxdepth 2 -path '*-dissection/.dissect-lock' -mmin -120 2>/dev/null | head -n 1)"
  [ -n "$lock_hit" ] && run_active="yes"
fi

# A write targeting a "*-dissection" path is in-scope even without a lock hit
# (a subagent's cwd can differ from where the output folder lives). Normalize
# backslashes first so Windows-style paths match. This only decides whether to
# RUN the decision logic below — the allow/ask verdict still comes from the
# canonicalized path, so a traversal like "x-dissection/../../etc" ends in
# "ask", never "allow".
case "$(printf '%s' "$file_path" | tr '\\' '/')" in
  *-dissection/*) run_active="yes" ;;
esac

# No active run, target unrelated to any dissection folder -> stay silent so
# the user's own permission flow decides. The hook must never nag outside runs.
if [ -z "$run_active" ]; then
  exit 0
fi
# ---------------------------------------------------------------------------

# Canonicalize. The target may not exist yet (a new file), so canonicalize the
# parent directory and re-append the basename. If NO canonicalization tool is
# available, leave $canon empty: we must NEVER make the security decision from a
# raw, un-normalized path (a raw "<x>-dissection/../../etc/passwd" would slip
# through the "*-dissection/*" glob). An empty $canon forces the "ask" branch.
# Normalize backslashes to forward slashes first: on Windows the harness may
# hand us "C:\Users\...\x-dissection\y.md", which dirname/realpath would treat
# as one opaque component and the "-dissection/" glob would never match — the
# specialists' own KB writes would then land in "ask" instead of "allow".
# (Literal backslashes in POSIX filenames are legal but vanishingly rare, and
# mis-normalizing one only ever degrades toward "ask", never toward "allow".)
file_path="$(printf '%s' "$file_path" | tr '\\' '/')"
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
