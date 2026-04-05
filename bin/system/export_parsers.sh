#!/bin/zsh
# ==============================================================================
# Title: Parser Registry Exporter
#
# Usage: tos system export-parsers
#
# Walks every module directory under $TOS_BIN, finds .config/parsers/parsers.json
# files, and emits a single merged JSON object keyed by module name to stdout.
# The Neovim client (and any other external consumer) calls this once at startup
# to cache the active synthetic protocol definitions.
# ==============================================================================

[[ -z "$SUDO_USER" || "$TOS_CONTROLLER_LOCKED" != "true" ]] && exit 1

OUTPUT="{}"

for parser_file in "$TOS_BIN"/*/".config/parsers/parsers.json"(N); do
    MODULE=$(basename "$(dirname "$(dirname "$parser_file")")")
    MODULE_JSON=$(cat "$parser_file" 2>/dev/null) || continue
    # Merge: wrap under module key using Python (available everywhere)
    OUTPUT=$(python3 -c "
import json, sys
merged = json.loads(sys.argv[1])
module_data = json.loads(sys.argv[2])
merged[sys.argv[3]] = module_data
print(json.dumps(merged, indent=2))
" "$OUTPUT" "$MODULE_JSON" "$MODULE" 2>/dev/null) || continue
done

echo "$OUTPUT"
