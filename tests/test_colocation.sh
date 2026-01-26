#!/bin/bash
# Test: Verify Colocation and Safety Guard.

echo "🧪 TEST: Project Creator (Refactor)"
SCRIPT_PATH="$(pwd)/bin/tos_project_creator.sh"
TEST_ZONE="/tmp/tos_test_zone_$(date +%s)"
mkdir -p "$TEST_ZONE/team_of_six" "$TEST_ZONE/llm_agents"

# --- CASE 1: SUCCESSFUL CREATION ---
echo "   Case 1: Creating 'alpha'..."
if (cd "$TEST_ZONE" && "$SCRIPT_PATH" "alpha" >/dev/null); then
    echo "   ✅ Case 1 Passed."
else
    echo "   ❌ Case 1 Failed."
    exit 1
fi

# --- CASE 2: PREVENT OVERWRITE ---
echo "   Case 2: Overwriting 'alpha' (Expect Fail)..."
OUTPUT=$(cd "$TEST_ZONE" && "$SCRIPT_PATH" "alpha" 2>&1)
if echo "$OUTPUT" | grep -q "already exists"; then
    echo "   ✅ Case 2 Passed: Overwrite blocked."
else
    echo "   ❌ Case 2 Failed: Script allowed overwrite."
    echo "      Output: $OUTPUT"
    exit 1
fi

# Cleanup
rm -rf "$TEST_ZONE"
echo "✅ ALL TESTS PASSED."
