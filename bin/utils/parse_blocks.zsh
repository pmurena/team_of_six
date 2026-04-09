#!/bin/zsh
# ==============================================================================
# Title: The Universal Inbox Reader (Conceptual Container ORM)
#
# Usage Explanation: This is the core data extraction utility. Instead of 
# formatting direct strings, it parses the LLM's raw text and converts it into 
# numbered directories (objects) containing safe, isolated text files for each 
# expected key. 
#
# Key-Value Mode (e.g., parse_blocks.zsh inbox ISSUE ./out TITLE BODY): 
# Extracts specific fields into separate files.
# 
# Raw File Mode (e.g., parse_blocks.zsh inbox FILE ./out): 
# Treats the entire block as raw text, extracting the target path into 
# `_TARGET.txt` and the content into `RAW_BODY.txt`.
# ==============================================================================

INPUT_FILE="$1"
PREFIX="$2"
OUT_DIR="$3"
shift 3
EXPECTED_KEYS=("$@")


if [[ -z "$INPUT_FILE" || -z "$PREFIX" || -z "$OUT_DIR" ]]; then
    echo "🚨 ERROR: Invalid arguments to parse_blocks.zsh" >&2
    exit 1
fi

mkdir -p "$OUT_DIR"
KEYS_STRING=$(IFS=,; echo "${EXPECTED_KEYS[*]}")

# Secure AWK Execution
awk -v outdir="$OUT_DIR" -v prefix="$PREFIX" -v keys_str="$KEYS_STRING" '
BEGIN {
    count=0; state="none"; current_key="";
    if (keys_str != "") { split(keys_str, keys, ","); }
    start_regex = "^===TOS_" prefix "_START";
    end_regex = "^===TOS_" prefix "_END===";
}

$0 ~ start_regex {
    count++;
    state="block";
    current_key="";
    system("mkdir -p \"" outdir "/" count "\"");

    # Extract optional target suffix (e.g., the file path in ===TOS_FILE_START: path===)
    suffix = $0;
    sub(start_regex, "", suffix);
    sub(/===$/, "", suffix);
    sub(/^:[ \t]*/, "", suffix);
    if (suffix != "") { print suffix > (outdir "/" count "/_TARGET.txt"); }

    # If no explicit keys are provided, treat the whole block as a raw body
    if (keys_str == "") { current_key = "RAW_BODY"; }
    next;
}

$0 ~ end_regex { state="none"; current_key=""; next; }

state=="block" {
    if (keys_str != "") {
        # Key-Value Mode (Issues, Comments, Meta)
        matched=0;
        for(i in keys) {
            key_prefix = keys[i] "=";
            if(index($0, key_prefix) == 1) {
                current_key = keys[i];
                sub("^" key_prefix, "");
                print $0 > (outdir "/" count "/" current_key ".txt");
                matched=1;
                break;
            }
        }
        if(matched==0 && current_key != "") { print $0 >> (outdir "/" count "/" current_key ".txt"); }
    } else {
        # Raw Body Mode (Files)
        print $0 >> (outdir "/" count "/" current_key ".txt");
    }
}
' "$INPUT_FILE"

[[ $? -ne 0 ]] && exit 1

# In Raw File Mode (FILE blocks), validate every parsed block has a _TARGET.txt.
# If it's missing, the Ghost wrote ===TOS_FILE_START=== without a path — fail loudly.
if [[ -z "$KEYS_STRING" ]]; then
    for item_dir in "$OUT_DIR"/*(N/); do
        if [[ ! -s "$item_dir/_TARGET.txt" ]]; then
            echo "🚨 ERROR: FILE block $(basename $item_dir) has no path." >&2
            echo "   Expected: ===TOS_FILE_START: path/to/file.ext===" >&2
            exit 1
        fi
    done
fi
