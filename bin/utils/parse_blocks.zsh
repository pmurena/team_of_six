#!/bin/zsh
# ==============================================================================
# Title: The Universal Inbox Reader (Conceptual Container ORM)
#
# Usage (auto-detect mode — used by tests and modules):
#   parse_blocks.zsh <input_file> <output_dir>
#
#   Parses all TOS protocol block types and writes fields into subdirectories:
#     <N>/          META block N     (bare number, e.g. "1")
#     file_<N>/     FILE block N
#     plan_<N>/     PLAN block N
#     issue_<N>/    ISSUE block N
#     comment_<N>/  COMMENT block N
#     trinity_<N>/  TRINITY block N
#
# Usage (legacy prefix mode — used by some production modules):
#   parse_blocks.zsh <input_file> <PREFIX> <output_dir> [KEY KEY ...]
# ==============================================================================

INPUT_FILE="$1"

if [[ -z "$INPUT_FILE" ]]; then
    echo "🚨 ERROR: parse_blocks.zsh requires at least an input file." >&2
    exit 1
fi

# ─── AUTO-DETECT MODE (2 args) ───────────────────────────────────────────────
if [[ $# -eq 2 ]]; then
    OUT_DIR="$2"
    mkdir -p "$OUT_DIR"

    awk -v outdir="$OUT_DIR" '
    BEGIN {
        meta_count    = 0
        file_count    = 0
        plan_count    = 0
        issue_count   = 0
        comment_count = 0
        trinity_count = 0
        state         = "none"
        current_dir   = ""
        current_key   = ""
        error         = 0
    }

    # ── openers ──────────────────────────────────────────────────────────────
    /^===TOS_META_START===/ {
        meta_count++
        current_dir = outdir "/" meta_count
        system("mkdir -p \"" current_dir "\"")
        state = "kv"; current_key = ""; next
    }
    /^===TOS_FILE_START/ {
        file_count++
        current_dir = outdir "/file_" file_count
        system("mkdir -p \"" current_dir "\"")
        suffix = $0
        sub(/^===TOS_FILE_START/, "", suffix)
        sub(/===$/, "", suffix)
        sub(/^:[ \t]*/, "", suffix)
        if (suffix == "") {
            print "🚨 ERROR: FILE block " file_count " has no path." > "/dev/stderr"
            print "   Expected: ===TOS_FILE_START: path/to/file.ext===" > "/dev/stderr"
            error = 1; state = "skip"; next
        }
        print suffix > (current_dir "/_TARGET.txt")
        state = "raw"; current_key = "RAW_BODY"; next
    }
    /^===TOS_PLAN_START===/ {
        plan_count++
        current_dir = outdir "/plan_" plan_count
        system("mkdir -p \"" current_dir "\"")
        state = "kv"; current_key = ""; next
    }
    /^===TOS_ISSUE_START===/ {
        issue_count++
        current_dir = outdir "/issue_" issue_count
        system("mkdir -p \"" current_dir "\"")
        state = "kv"; current_key = ""; next
    }
    /^===TOS_COMMENT_START===/ {
        comment_count++
        current_dir = outdir "/comment_" comment_count
        system("mkdir -p \"" current_dir "\"")
        state = "kv"; current_key = ""; next
    }
    /^===TOS_TRINITY_START===/ {
        trinity_count++
        current_dir = outdir "/trinity_" trinity_count
        system("mkdir -p \"" current_dir "\"")
        state = "kv"; current_key = ""; next
    }

    # ── closers ───────────────────────────────────────────────────────────────
    /^===TOS_(META|FILE|PLAN|ISSUE|COMMENT|TRINITY)_END===/ {
        state = "none"; current_dir = ""; current_key = ""; next
    }

    # ── body: key-value mode ─────────────────────────────────────────────────
    state == "kv" {
        if ($0 ~ /^[A-Z_]+=/) {
            eq = index($0, "=")
            current_key = substr($0, 1, eq - 1)
            print substr($0, eq + 1) > (current_dir "/" current_key ".txt")
        } else if (current_key != "") {
            print $0 >> (current_dir "/" current_key ".txt")
        }
        next
    }

    # ── body: raw mode ────────────────────────────────────────────────────────
    state == "raw" {
        print $0 >> (current_dir "/" current_key ".txt")
        next
    }

    END { exit error }
    ' "$INPUT_FILE"

    exit $?
fi

# ─── LEGACY PREFIX MODE (3+ args) ────────────────────────────────────────────
PREFIX="$2"
OUT_DIR="$3"
shift 3
EXPECTED_KEYS=("$@")

if [[ -z "$PREFIX" || -z "$OUT_DIR" ]]; then
    echo "🚨 ERROR: Invalid arguments to parse_blocks.zsh" >&2
    exit 1
fi

mkdir -p "$OUT_DIR"
KEYS_STRING=$(IFS=,; echo "${EXPECTED_KEYS[*]}")

awk -v outdir="$OUT_DIR" -v prefix="$PREFIX" -v keys_str="$KEYS_STRING" '
BEGIN {
    count=0; state="none"; current_key="";
    if (keys_str != "") { split(keys_str, keys, ","); }
    start_regex = "^===TOS_" prefix "_START";
    end_regex   = "^===TOS_" prefix "_END===";
}

$0 ~ start_regex {
    count++;
    state="block";
    current_key="";
    system("mkdir -p \"" outdir "/" count "\"");

    suffix = $0;
    sub(start_regex, "", suffix);
    sub(/===$/, "", suffix);
    sub(/^:[ \t]*/, "", suffix);
    if (suffix != "") { print suffix > (outdir "/" count "/_TARGET.txt"); }

    if (keys_str == "") { current_key = "RAW_BODY"; }
    next;
}

$0 ~ end_regex { state="none"; current_key=""; next; }

state=="block" {
    if (keys_str != "") {
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
        print $0 >> (outdir "/" count "/" current_key ".txt");
    }
}
' "$INPUT_FILE"

[[ $? -ne 0 ]] && exit 1

if [[ -z "$KEYS_STRING" ]]; then
    for item_dir in "$OUT_DIR"/*(N/); do
        if [[ ! -s "$item_dir/_TARGET.txt" ]]; then
            echo "🚨 ERROR: FILE block $(basename $item_dir) has no path." >&2
            echo "   Expected: ===TOS_FILE_START: path/to/file.ext===" >&2
            exit 1
        fi
    done
fi
