#!/bin/zsh
# ==============================================================================
# Mutator: CIT Triad, Path-Based Locks, & Validated Trinity Closure
# ==============================================================================

echo "⚡ Creating new directory structure..."
mkdir -p bin/write/soft bin/write/hard bin/sync/soft

echo "⚡ Moving and renaming scripts (skipping already moved files)..."
[ -f bin/write/comment.sh ] && mv bin/write/comment.sh bin/write/soft/
[ -f bin/write/tasks.sh ]   && mv bin/write/tasks.sh bin/write/soft/issue.sh
[ -f bin/write/code.sh ]    && mv bin/write/code.sh bin/write/hard/
[ -f bin/remove.sh ]        && mv bin/remove.sh bin/write/hard/trinity.sh
[ -f bin/sync/start.sh ]    && mv bin/sync/start.sh bin/sync/soft/
[ -f bin/sync/trinity.sh ]  && mv bin/sync/trinity.sh bin/sync/soft/
[ -f bin/sync/peek.sh ]     && mv bin/sync/peek.sh bin/sync/soft/

echo "⚡ Applying Python mutations to codebase..."
python3 - << 'EOF_PYTHON'
import json, re, os

# 1. Update bin/write/.config/parsers/parsers.json
with open("bin/write/.config/parsers/parsers.json", "r") as f:
    data = json.load(f)
data["parsers"]["TRINITY"] = {
    "start": "===TOS_TRINITY_START===",
    "end":   "===TOS_TRINITY_END===",
    "mode":  "kv",
    "keys":  ["TARGET_PROJECT", "TARGET_TRINITY", "MANIFEST"]
}
with open("bin/write/.config/parsers/parsers.json", "w") as f:
    json.dump(data, f, indent=2)

# 2. Update bin/write/tos
with open("bin/write/tos", "w") as f:
    f.write('''#!/bin/zsh
[[ -z "$SUDO_USER" || "$TOS_CONTROLLER_LOCKED" != "true" ]] && exit 1
PROJECT_NAME="$1"
ACTION="$2"
case "$ACTION" in
    "code")    "$TOS_BIN/write/hard/code.sh"    "$PROJECT_NAME" ;;
    "issue")   "$TOS_BIN/write/soft/issue.sh"   "$PROJECT_NAME" ;;
    "comment") "$TOS_BIN/write/soft/comment.sh" "$PROJECT_NAME" ;;
    "trinity") "$TOS_BIN/write/hard/trinity.sh" "$PROJECT_NAME" ;;
    *) echo "Usage: tos <project> write <code|issue|comment|trinity>"; exit 1 ;;
esac
''')

# 3. Update bin/sync/tos
with open("bin/sync/tos", "w") as f:
    f.write('''#!/bin/zsh
[[ -z "$SUDO_USER" || "$TOS_CONTROLLER_LOCKED" != "true" ]] && exit 1
PROJECT_NAME="$1"
ACTION="$2"
shift 2
case "$ACTION" in
    "start")     "$TOS_BIN/sync/soft/start.sh"   "$PROJECT_NAME" ;;
    "trinity")   "$TOS_BIN/sync/soft/trinity.sh" "$PROJECT_NAME" "$@" ;;
    "peek")      "$TOS_BIN/sync/soft/peek.sh"    "$PROJECT_NAME" "$@" ;;
    *) echo "Usage: tos <project> sync <start|trinity <ID>|peek <files...>>"; exit 1 ;;
esac
''')

# 4. Update bin/tos (Gateway Path-Based Locks)
with open("bin/tos", "r") as f:
    content = f.read()

# Only strip the old Trinity 0 condition if it hasn't been stripped yet
if "# Trinity 0 soft-lock blocks code writes only" in content:
    content = re.sub(r'    # Trinity 0 soft-lock blocks code writes only.*?\n    fi\n\n', '', content, flags=re.DOTALL)

# Only inject dispatch if not already injected
if "SUB_PATH=" not in content:
    new_dispatch = '''
    # --- Dispatch & Lock Enforcement ---
    ACTION="$1"
    SUB_PATH="soft"
    if [[ "$MODULE" == "write" ]]; then
        case "$ACTION" in
            code|trinity) SUB_PATH="hard" ;;
        esac
    fi

    if [[ "$SUB_PATH" == "hard" && "$TOS_ACTIVE_TRINITY" == "0" ]]; then
        echo "🚨 [ERROR] Write Denied: This operation requires a Hard Lock. Sync to a feature Trinity Turn." >&2
        exit 1
    fi

    case "$MODULE" in
        "sync")   TARGET_SCRIPT="$TOS_BIN/sync/tos" ;;
        "write")  TARGET_SCRIPT="$TOS_BIN/write/tos" ;;
        "system") TARGET_SCRIPT="$TOS_BIN/system/tos" ;;
        *) echo "Usage: tos <project> <sync|write|system> <action>"; exit 1 ;;
    esac

    { "$TARGET_SCRIPT" "$PROJECT_NAME" "$@" } 2>&1 | tee "$TOS_CONTEXT"
'''
    content = re.sub(r'    \{\n        case "\$MODULE" in.*?tee "\$TOS_CONTEXT"\n', new_dispatch.lstrip(), content, flags=re.DOTALL)

with open("bin/tos", "w") as f:
    f.write(content)

# 5. Rewrite bin/write/hard/trinity.sh
with open("bin/write/hard/trinity.sh", "w") as f:
    f.write('''#!/bin/zsh
# ==============================================================================
# Title: Validated Trinity Finalizer
# Usage: tos <project> write trinity
# ==============================================================================
[[ -z "$SUDO_USER" || "$TOS_CONTROLLER_LOCKED" != "true" ]] && exit 1

cd "$TOS_SANDBOX/$TOS_ACTIVE_PROJECT" || exit 1

PARSE_DIR="$TOS_PARSE_DIR/trinity"
"$TOS_BIN/utils/parse_blocks.sh" "$TOS_INPUT" "TRINITY" "$PARSE_DIR" "TARGET_PROJECT" "TARGET_TRINITY" "MANIFEST"

PAYLOAD_TRINITY=$(cat "$PARSE_DIR/1/TARGET_TRINITY.txt" 2>/dev/null)
[[ "$PAYLOAD_TRINITY" != "$TOS_ACTIVE_TRINITY" ]] && { echo "🚨 Hallucination: Trinity ID mismatch."; exit 1; }

echo "🔍 Auditing Context Integrity..."
AGENT_MANIFEST=$(cat "$PARSE_DIR/1/MANIFEST.txt" 2>/dev/null | tr ' ' '\\n' | sed '/^$/d' | sort)
ACTUAL_DIFF=$(git diff --name-only origin/main...HEAD | sort)

if [[ "$AGENT_MANIFEST" != "$ACTUAL_DIFF" ]]; then
    echo "🚨 CONTEXT HALLUCINATION DETECTED"
    echo "--- Agent Declared Manifest ---"
    echo "$AGENT_MANIFEST"
    echo "--- Actual Sandbox Diff ---"
    echo "$ACTUAL_DIFF"
    exit 1
fi

truncate -s 0 "$TOS_INPUT"
REV_HASH=$(git rev-parse --short HEAD)
ISSUE_URL=$(gh issue view "$TOS_ACTIVE_TRINITY" --json url -q .url 2>/dev/null || echo "Unknown URL")
COMMENT="[VERIFIED] Trinity #$TOS_ACTIVE_TRINITY finalized at rev $REV_HASH. Audit Manifest match: OK.\\nContext: $ISSUE_URL"

gh issue comment "$TOS_ACTIVE_TRINITY" -b "$COMMENT" 2>/dev/null || true
gh pr close "tos-work-$TOS_ACTIVE_TRINITY" -c "$COMMENT" 2>/dev/null || true
gh issue close "$TOS_ACTIVE_TRINITY" -r "completed" 2>/dev/null || true

git push origin --delete "tos-work-$TOS_ACTIVE_TRINITY" 2>/dev/null || true
git checkout main -q && git branch -D "tos-work-$TOS_ACTIVE_TRINITY" -q 2>/dev/null || true

"$TOS_BIN/utils/lock/release.sh" "$TOS_ACTIVE_PROJECT"
"$TOS_BIN/sync/soft/trinity.sh" "$TOS_ACTIVE_PROJECT" "0"
echo "🏁 Trinity Turn Finalized."
''')

# 6. Update export_parsers.sh (Support recursive search)
with open("bin/system/export_parsers.sh", "r") as f:
    c = f.read()
if "/**/" not in c:
    c = c.replace('"$TOS_BIN"/*/', '"$TOS_BIN"/**/')
    with open("bin/system/export_parsers.sh", "w") as f:
        f.write(c)

# 7. Update tos_bridge.lua (Neovim Mnemonic CIT Triad)
with open("plugins/neovim/lua/tos_bridge.lua", "r") as f:
    c = f.read()

c = c.replace('"tasks"', '"issue"')
c = c.replace('write_action("tasks")', 'write_action("issue")')
c = c.replace('opts("Sync Start")', 'opts("[S]ync Start")')
c = c.replace('opts("Sync Trinity (local)")', 'opts("Sync [T]rinity (local)")')
c = c.replace('opts("Sync Trinity (global)")', 'opts("Sync [T]rinity (global)")')
c = c.replace('opts("Sync Peek")', 'opts("Sync [P]eek")')
c = c.replace('opts("Write Code")', 'opts("Write [C]ode")')
c = c.replace('opts("Write Comment")', 'opts("Write Comment")')
c = c.replace('opts("Write Tasks")', 'opts("Write [I]ssue")')
c = c.replace('name = "+Sync with 6"', 'name = "+[S]ync with 6"')
c = c.replace('name = "+Write to 6"', 'name = "+[W]rite to 6"')

if "Write [T]rinity" not in c:
    c = re.sub(r'vim\.keymap\.set\("n", "<leader>6wt", function\(\) write_action\("issue"\)   end, opts\("Write \[I\]ssue"\)\)',
               'vim.keymap.set("n", "<leader>6wi", function() write_action("issue") end, opts("Write [I]ssue"))\\n    vim.keymap.set("n", "<leader>6wt", function() write_action("trinity") end, opts("Write [T]rinity"))', c)
    c = c.replace('"<leader>6wt"', '"<leader>6wi", "<leader>6wt"')

with open("plugins/neovim/lua/tos_bridge.lua", "w") as f:
    f.write(c)

# 8. Update llm_agents/code.md
with open("llm_agents/code.md", "r") as f:
    c = f.read()
c = c.replace("tos write tasks", "tos write issue")
c = c.replace("write tasks", "write issue")
c = c.replace("Write tasks", "Write issue")

final_str = "\\n6. **Finalization** (Trinity 1+): When the feature is complete or being dropped, you must execute `tos write trinity`. This requires a `===TOS_TRINITY_START===` block containing a `MANIFEST` key. The MANIFEST must precisely list every file changed in the sandbox compared to main, exactly matching `git diff --name-only origin/main...HEAD`. If you hallucinate the manifest, the Ghost will reject the closure."

if "When the feature is complete or being dropped" not in c:
    c = re.sub(r'(5\. \*\*Retrospect\*\*.*?mandatory\.)', r'\1' + final_str, c, flags=re.DOTALL)
    with open("llm_agents/code.md", "w") as f:
        f.write(c)

# 9. Update interactive_tutorial.zsh (Fix Chapter 10)
with open("test/interactive_tutorial.zsh", "r") as f:
    c = f.read()

ch10_replacement = """show_role "$CYAN" "AGENT" "Providing MANIFEST to validate closure."
PAYLOAD_TRINITY=$(cat << 'EOF'
===TOS_TRINITY_START===
TARGET_PROJECT=$TEST_REPO
TARGET_TRINITY=1
MANIFEST=README.md
calculator.zsh
llm_agents/code.md
test_calculator.zsh
===TOS_TRINITY_END===
EOF
)
echo "$PAYLOAD_TRINITY" > "$TOS_INPUT"

show_role "$PURPLE" "GHOST" "Executing: tos write trinity"
"$TOS_BIN_CMD" "$TEST_REPO" write trinity
"""

# Only replace if the old Architect line exists
if "Merging PR and syncing local branches" in c:
    c = re.sub(r'show_role "\$YELLOW" "ARCHITECT" "Merging PR and syncing local branches\.\.\.".*?(?=show_role "\$PURPLE" "GHOST" "Session closed\.)', ch10_replacement, c, flags=re.DOTALL)
    with open("test/interactive_tutorial.zsh", "w") as f:
        f.write(c)

EOF_PYTHON

echo "⚡ Making subscripts executable..."
chmod +x bin/write/soft/*.sh bin/write/hard/*.sh bin/sync/soft/*.sh bin/write/tos bin/sync/tos 2>/dev/null || true

echo "✅ CIT Triad Refactor complete."
