#!/usr/bin/env bash
# check-sync.sh — verify the zero-install mirror matches the plugin component dirs.
#
# The repo ships two byte-identical copies of the agent/skill/command files:
#   .claude/{agents,skills,commands}/  (canonical, drives the zero-install path)
#   {agents,skills,commands}/          (plugin component dirs, packaged by .claude-plugin)
# Any edit to a file present in both MUST be applied identically to BOTH copies.
# This script diffs all three pairs and exits nonzero on any drift, so it can be
# wired into CI or a pre-commit check.

set -u

# Run from the repository root regardless of where the script was invoked.
cd "$(dirname "$0")/.." || exit 2

diff -r .claude/agents agents \
  && diff -r .claude/skills skills \
  && diff -r .claude/commands commands \
  && { echo "mirror in sync"; exit 0; }

echo "❌ mirror drift detected — .claude/{agents,skills,commands} and the repo-root copies differ (see diff above)." >&2
exit 1
