#!/usr/bin/env bash
# =============================================================================
# pre-commit-check.sh — run before EVERY git add/commit.
# Blocks commit if any file is >20% shorter than HEAD (likely truncated).
# Also warns on obvious truncated endings (mid-identifier, mid-string).
# Usage: bash .claude/pre-commit-check.sh [file1 file2 ...]
#   No args = check all files modified vs HEAD
# =============================================================================
set -uo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

if [ $# -gt 0 ]; then
    FILES=("$@")
else
    mapfile -t FILES < <(git diff --name-only HEAD 2>/dev/null || true)
fi

if [ ${#FILES[@]} -eq 0 ]; then
    echo -e "${GREEN}✓ No modified files to check.${NC}"
    exit 0
fi

FAIL=0

for f in "${FILES[@]}"; do
    [ -f "$f" ] || continue

    wt_lines=$(wc -l < "$f" | tr -d '[:space:]')
    head_lines=$(git show HEAD:"$f" 2>/dev/null | wc -l | tr -d '[:space:]')
    head_lines=${head_lines:-0}

    # --- Hard fail: file shortened >20% vs HEAD
    if [ "$head_lines" -gt 5 ]; then
        threshold=$(( head_lines * 90 / 100 ))
        if [ "$wt_lines" -lt "$threshold" ]; then
            pct=$(( (head_lines - wt_lines) * 100 / head_lines ))
            echo -e "${RED}✗ TRUNCATED: $f${NC}"
            echo -e "  HEAD=${head_lines}L  WT=${wt_lines}L  (${pct}% shorter than HEAD)"
            echo -e "  Restore: git show HEAD:$f > $f"
            FAIL=1
            continue
        fi
    fi

    # --- Warn: last line looks like a mid-expression cut
    # Patterns: ends with lowercase identifier + nothing (not a comment, not a keyword line)
    last_raw=$(tail -1 "$f")
    last_trimmed=$(echo "$last_raw" | sed 's/^[[:space:]]*//' | tr -d '[:space:]')
    ext="${f##*.}"

    suspicious=0
    if [[ "$ext" =~ ^(cs|razor|ts|js)$ ]]; then
        # Last line ends mid-identifier: no closing punctuation, not a keyword/directive line
        if echo "$last_raw" | grep -qE '[a-zA-Z_][a-zA-Z0-9_]*$' && \
           ! echo "$last_raw" | grep -qE '^\s*(//|#|@|using|namespace|public|private|protected|internal|static|class|interface|record|enum|override|return|await|var|let|const)'; then
            suspicious=1
        fi
    fi

    if [ "$suspicious" -eq 1 ]; then
        echo -e "${YELLOW}⚠ SUSPICIOUS ENDING: $f${NC}"
        echo -e "  Last line: $last_raw"
        echo -e "  Verify this is not a truncated file."
        # Don't fail, just warn — could be a valid method call on last line
    fi

    if [ "$FAIL" -eq 0 ] && [ "$suspicious" -eq 0 ]; then
        echo -e "${GREEN}✓ $f (${wt_lines}L)${NC}"
    elif [ "$suspicious" -eq 1 ]; then
        echo -e "${YELLOW}  $f (${wt_lines}L) — review last line${NC}"
    fi
done

echo ""
if [ "$FAIL" -ne 0 ]; then
    echo -e "${RED}BLOCKED — DO NOT COMMIT. Restore truncated files first.${NC}"
    exit 1
else
    echo -e "${GREEN}Size checks passed.${NC}"
    exit 0
fi
