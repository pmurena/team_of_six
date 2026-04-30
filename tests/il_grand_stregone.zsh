#!/usr/bin/env zsh
# =============================================================================
# tests/il_grand_stregone.zsh (The Great Sorcerer - Test Hypervisor)
# =============================================================================

setopt ERR_EXIT NOUNSET PIPE_FAIL 2>/dev/null || set -euo pipefail

# ---------------------------------------------------------------------------
# 1. Parse Arguments
# ---------------------------------------------------------------------------
STAGES=()

if [[ $# -eq 0 ]]; then
    STAGES=("unit" "integration" "system")
else
    if [[ "$1" == "--test" ]]; then
        shift
        if [[ $# -eq 0 ]]; then
            echo "🚨 ERROR: --test requires arguments (e.g. unit, system, or a file path)."
            exit 1
        fi
    fi
    STAGES=("$@")
fi

# ---------------------------------------------------------------------------
# 2. Compile the Execution Queue (Fail-Fast Validation)
# ---------------------------------------------------------------------------
EXECUTION_QUEUE=()

for stage in "${STAGES[@]}"; do
    case "$stage" in
        unit)
            EXECUTION_QUEUE+=("zunit:tests/unit")
            ;;
        integration)
            EXECUTION_QUEUE+=("zunit:tests/integration")
            ;;
        system)
            sys_files=(tests/system/test_*.zsh(N))
            if [[ ${#sys_files[@]} -eq 0 ]]; then
                echo "🚨 ERROR: No test files found matching tests/system/test_*.zsh"
                exit 1
            fi
            for f in "${sys_files[@]}"; do
                EXECUTION_QUEUE+=("file:$f")
            done
            ;;
        *)
            if [[ -f "$stage" ]]; then
                EXECUTION_QUEUE+=("file:$stage")
            else
                echo "🚨 ERROR: Unknown stage or file not found -> '$stage'"
                exit 1
            fi
            ;;
    esac
done

if [[ ${#EXECUTION_QUEUE[@]} -eq 0 ]]; then
    echo "🚨 ERROR: The execution queue is empty. Nothing to do."
    exit 1
fi

# ---------------------------------------------------------------------------
# 3. The Universal Trap
# ---------------------------------------------------------------------------
function _graceful_exit() {
    local _exit_code=$?
    echo ""
    echo "═══ STREGONE TRAP: Teardown Initiated ═══"
    
    if type "grace_payload_teardown" >/dev/null 2>&1; then
        grace_payload_teardown
    fi
    
    if [[ $_exit_code -ne 0 ]]; then
        echo "🚨 STREGONE HALT: Execution collapsed with exit code $_exit_code."
    else
        echo "✨ STREGONE SUCCESS: All requested sequences completed."
    fi
    exit $_exit_code
}
trap '_graceful_exit' EXIT INT TERM

# ---------------------------------------------------------------------------
# 4. Pre-Flight: Chaos Drill
# ---------------------------------------------------------------------------
_subshell_exit=0
zsh -c '
    trap "touch /tmp/stregone_99.proof" EXIT
    exit 99
' || _subshell_exit=$?

if [[ "${_subshell_exit}" -eq 99 && -f "/tmp/stregone_99.proof" ]]; then
    rm "/tmp/stregone_99.proof"
else
    _proof_exists="NO"
    [[ -f "/tmp/stregone_99.proof" ]] && _proof_exists="YES"
    
    echo "🚨 [FATAL] Trap failed Chaos Drill." >&2
    echo "   Expected Exit: 99 | Actual Exit: ${_subshell_exit}" >&2
    echo "   Proof File Created: ${_proof_exists}" >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# 5. Execution Engine
# ---------------------------------------------------------------------------
function execute_payload() {
    local target="$1"
    echo "🚀 STREGONE: Sourcing script -> $target"
    source "$target"
    
    if type "grace_payload_teardown" >/dev/null 2>&1; then
        grace_payload_teardown
        unset -f grace_payload_teardown
    fi
}

echo "🔮 STREGONE: Validated execution queue. Commencing..."

for task in "${EXECUTION_QUEUE[@]}"; do
    echo ""
    if [[ "$task" == zunit:* ]]; then
        local target_dir="${task#zunit:}"
        echo "🧪 STREGONE: Executing ZUnit -> $target_dir"
        zunit "$target_dir"
    elif [[ "$task" == file:* ]]; then
        local target_file="${task#file:}"
        execute_payload "$target_file"
    fi
done
