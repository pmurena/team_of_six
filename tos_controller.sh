#!/bin/zsh
# V55 Controller
# Dispatches commands to the binary logic.

REPO_DIR="$(dirname "$(readlink -f "${(%):-%x}")")"
BIN_DIR="$REPO_DIR/bin"

COMMAND=$1

# 1. Handle "No Parameters" case first
if [ -z "$COMMAND" ]; then
    exec "$BIN_DIR/tos_wrapper.sh"
fi

# 2. Shift if there are arguments to pass along
shift 2>/dev/null || true 

# 3. Dispatch known commands or error out
case "$COMMAND" in
    new)
        exec "$BIN_DIR/tos_project_creator.sh" "$@"
        ;;
    install)
        exec "$BIN_DIR/tos_installer.sh" "$@"
        ;;
    wrapper)
        exec "$BIN_DIR/tos_wrapper.sh" "$@"
        ;;
    publish)
        exec "$BIN_DIR/tos_publish.sh" "$@"
        ;;
    new)
        exec "$BIN_DIR/tos_project_creator.sh" "$@"
        ;;
    uninstall)
        exec "$BIN_DIR/tos_uninstall.sh" "$@"
        ;;
   *)
        echo "Error: Unknown command '$COMMAND'" >&2
        echo "Usage: team_of_six [install|wrapper|publish|uninstall]" >&2
        exit 1
        ;;
esac
