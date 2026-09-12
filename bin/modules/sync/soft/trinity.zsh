#!/bin/zsh
# ==============================================================================
# Title: Atomic Handover + Clean Room Snapshot
# Usage: tos <project> sync trinity <ID>
#
# Performs the Atomic Handover (03-trinity.md) and regenerates the Clean Room
# Snapshot in the Architect's outbox:
#
#   1. Push the outgoing branch (only when leaving a hard lock)
#   2. Release the old lock
#   3. Acquire the new lock
#   4. Fetch, check out the target branch, fast-forward from origin
#   5. Emit the snapshot to stdout (the gateway tees it to the outbox)
#
# The push in step 1 is the safety guarantee: the Ghost's work reaches the
# remote before any local state changes. Step 4 uses --ff-only — a divergence
# halts the sync rather than being silently resolved (ADR: Out-of-Band
# Recovery Doctrine).
# ==============================================================================
[[ -z "$SUDO_USER" || "$TOS_CONTROLLER_LOCKED" != "true" ]] && exit 1

PROJECT_NAME="${1:-$TOS_ACTIVE_PROJECT}"
NEW_TRINITY="$2"

if [[ -z "$NEW_TRINITY" ]]; then
    echo "🚨 [ERROR] sync trinity: Missing trinity ID." >&2
    echo "    Usage: tos $PROJECT_NAME sync trinity <ID>" >&2
    exit 1
fi

if [[ ! "$NEW_TRINITY" =~ ^[0-9]+$ ]]; then
    echo "🚨 [ERROR] sync trinity: Trinity ID must be numeric (got '$NEW_TRINITY')." >&2
    exit 1
fi

cd "$TOS_SANDBOX/$PROJECT_NAME" || {
    echo "🚨 [ERROR] No sandbox for '$PROJECT_NAME'." >&2
    echo "    Run: tos $PROJECT_NAME sync project" >&2
    exit 1
}

echo "🔄 Syncing Trinity..."

# --- 1. PRESERVE -------------------------------------------------------------
if [[ -n "$TOS_ACTIVE_TRINITY" && "$TOS_ACTIVE_TRINITY" -gt 0 ]]; then
    OUTGOING="tos-work-$TOS_ACTIVE_TRINITY"
    if git show-ref --verify --quiet "refs/heads/$OUTGOING"; then
        echo "⬆️  Preserving $OUTGOING on remote before handover..."
        git push origin "$OUTGOING" || {
            echo "🚨 FATAL: Push failed. Halting sync — no self-healing." >&2
            echo "    Resolve on the remote, then re-run this command." >&2
            exit 1
        }
    else
        echo "⏭️  $OUTGOING no longer exists locally. Nothing to preserve."
    fi
else
    echo "⏭️  Project Soft Lock detected (Trinity 0). Skipping push."
fi

# --- 2. HANDOVER -------------------------------------------------------------
"$TOS_BIN/utils/lock/release.zsh" "$PROJECT_NAME" >/dev/null 2>&1
"$TOS_BIN/utils/lock/acquire.zsh" "$PROJECT_NAME" "$NEW_TRINITY" "$SUDO_USER" >/dev/null 2>&1 || {
    echo "🚨 [ERROR] Failed to acquire lock for trinity $NEW_TRINITY." >&2
    exit 1
}

# --- 3. ALIGN ----------------------------------------------------------------
git fetch origin --prune -q || {
    echo "🚨 FATAL: git fetch failed. Halting sync." >&2
    exit 1
}

if [[ "$NEW_TRINITY" == "0" ]]; then
    TARGET_BRANCH="main"
else
    TARGET_BRANCH="tos-work-$NEW_TRINITY"
fi

if git show-ref --verify --quiet "refs/heads/$TARGET_BRANCH"; then
    git checkout "$TARGET_BRANCH" -q
elif git show-ref --verify --quiet "refs/remotes/origin/$TARGET_BRANCH"; then
    git checkout -b "$TARGET_BRANCH" --track "origin/$TARGET_BRANCH" -q
else
    echo "🚨 [ERROR] Branch '$TARGET_BRANCH' exists neither locally nor on origin." >&2
    echo "    Run: tos $PROJECT_NAME create trinity $NEW_TRINITY" >&2
    exit 1
fi

# Absorb any Architect review commits. --ff-only: a divergence is the
# Architect's to resolve, not the Ghost's.
if git show-ref --verify --quiet "refs/remotes/origin/$TARGET_BRANCH"; then
    git pull --ff-only origin "$TARGET_BRANCH" -q || {
        echo "🚨 FATAL: '$TARGET_BRANCH' has diverged from origin/$TARGET_BRANCH." >&2
        echo "    Resolve out-of-band, then re-run this command." >&2
        exit 1
    }
fi

echo "✅ Sync complete. Handed over to trinity $NEW_TRINITY on $TARGET_BRANCH."

# --- 4. CLEAN ROOM SNAPSHOT --------------------------------------------------
echo ""
echo "=== TOS CLEAN ROOM SNAPSHOT ==="
echo "TARGET_PROJECT=$PROJECT_NAME"
echo "TARGET_TRINITY=$NEW_TRINITY"
echo "BRANCH=$TARGET_BRANCH"
echo "GENERATED=$(date '+%Y-%m-%d %H:%M:%S')"

# PHASE GATE — the snapshot must not carry an unvalidated phase. Every read
# validates in full (invariant 7); there is no fast path. A failure here halts
# the sync rather than emitting a phase the Agent would act on confidently.
if [[ "$NEW_TRINITY" != "0" ]]; then
    PHASE_NOW=$("$TOS_BIN/utils/phase_validate.zsh" verify "$PROJECT_NAME" "$NEW_TRINITY") || {
        echo "" >&2
        echo "🚨 FATAL: the phase record failed validation. No snapshot emitted." >&2
        echo "    The Agent must not receive a context whose phase cannot be trusted." >&2
        echo "    Recovery: tos $PROJECT_NAME close trinity" >&2
        exit 1
    }
    echo "PHASE=$PHASE_NOW"
fi

if [[ "$NEW_TRINITY" != "0" ]]; then
    echo ""
    echo "## ISSUE #$NEW_TRINITY"
    gh issue view "$NEW_TRINITY" --comments 2>/dev/null \
        || echo "_(no issue found for #$NEW_TRINITY)_"

    echo ""
    echo "## PULL REQUEST"
    if gh pr view "$TARGET_BRANCH" &>/dev/null; then
        gh pr view "$TARGET_BRANCH" --comments 2>/dev/null
    else
        echo "_(no pull request open for $TARGET_BRANCH)_"
    fi

    echo ""
    echo "## CHANGED FILES (vs origin/main)"
    git diff --name-only origin/main...HEAD 2>/dev/null || echo "_(none)_"

    echo ""
    echo "## DIFF vs origin/main"
    echo '```diff'
    git diff origin/main...HEAD 2>/dev/null
    echo '```'
else
    echo ""
    echo "## OPEN ISSUES"
    gh issue list 2>/dev/null || echo "_(unavailable)_"

    echo ""
    echo "## OPEN PULL REQUESTS"
    gh pr list 2>/dev/null || echo "_(none)_"
fi

echo ""
echo "## REPOSITORY SIGNATURE MAP"
if command -v ctags >/dev/null 2>&1; then
    ctags -R -x --_xformat="%-32N %-12K %5n  %F" . 2>/dev/null | head -n 250
else
    git ls-files
fi

echo ""
echo "## WORKING TREE"
git status -s

echo ""
echo "## RECENT COMMITS"
git log --oneline -10

echo ""
echo "=== END SNAPSHOT ==="
