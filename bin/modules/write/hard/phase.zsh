#!/bin/zsh
# ==============================================================================
# Title: Phase Transition
# Usage: tos <project> write phase
#
# Applies the latest transition tag the Architect has submitted on the
# Trinity's pull request. All validation lives in utils/phase_validate.zsh;
# this module is deliberately thin.
#
# hard/ placement means an active trinity is required — the gateway enforces
# that before dispatch.
# ==============================================================================
[[ -z "$SUDO_USER" || "$TOS_CONTROLLER_LOCKED" != "true" ]] && exit 1

PROJECT_NAME="${1:-$TOS_ACTIVE_PROJECT}"

cd "$TOS_SANDBOX/$PROJECT_NAME" || {
    echo "🚨 [ERROR] No sandbox for '$PROJECT_NAME'." >&2
    exit 1
}

echo "🔍 Validating the phase record against GitHub..."

BEFORE=$("$TOS_BIN/utils/phase_validate.zsh" verify "$PROJECT_NAME" "$TOS_ACTIVE_TRINITY") || exit 1

AFTER=$("$TOS_BIN/utils/phase_validate.zsh" apply "$PROJECT_NAME" "$TOS_ACTIVE_TRINITY") || exit 1

echo "✅ Phase transition applied: ${BEFORE} → ${AFTER}"
echo ""
echo "TARGET_PROJECT=$PROJECT_NAME"
echo "TARGET_TRINITY=$TOS_ACTIVE_TRINITY"
echo "PHASE=$AFTER"

if [[ "$AFTER" == "retrospect" ]]; then
    echo ""
    echo "The Retrospective is the final phase. Once its learnings are committed,"
    echo "run: tos $PROJECT_NAME write trinity"
fi
