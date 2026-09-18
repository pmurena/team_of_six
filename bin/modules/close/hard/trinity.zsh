#!/bin/zsh
[[ -z "$SUDO_USER" || "$TOS_CONTROLLER_LOCKED" != "true" ]] && exit 1
[[ ! -s "$TOS_INPUT" ]] && exit 1

# HITL Gate (ADR 12)
grep -q "CONFIRM=TRUE" "$TOS_INPUT" || { echo "🚨 [ERROR] Safety gate: CONFIRM=TRUE required." >&2; exit 1; }

truncate -s 0 "$TOS_INPUT"
# create trinity opens the PR with --draft: a Trinity in Red is work in
# progress and the draft flag says so. GitHub refuses to merge a draft, and
# nothing else ever clears it, so this is where it has to come off.
#
# Tolerant of failure: a PR that is already out of draft returns non-zero,
# and that is not an error worth halting a merge over.
gh pr ready "tos-work-$TOS_ACTIVE_TRINITY" 2>/dev/null || true

gh pr merge "tos-work-$TOS_ACTIVE_TRINITY" --squash --delete-branch
# The Trinity is closed: purge its visa and phase record with the lock.
"$TOS_BIN/utils/lock/release.zsh" "$TOS_ACTIVE_PROJECT" --purge
gh issue close "$TOS_ACTIVE_TRINITY" -r "completed" 2>/dev/null || true
echo "🏁 Trinity #$TOS_ACTIVE_TRINITY closed."
