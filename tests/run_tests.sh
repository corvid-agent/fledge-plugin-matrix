#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BIN="$PLUGIN_DIR/bin/matrix"

export FLEDGE_PLUGIN_DIR="$PLUGIN_DIR"

PASS=0
FAIL=0

assert_exit() {
    local expected="$1"
    shift
    local desc="$1"
    shift

    local rc=0
    "$@" > /dev/null 2>&1 || rc=$?
    if [[ "$rc" -eq "$expected" ]]; then
        echo "  PASS: $desc"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $desc (expected exit $expected, got $rc)"
        FAIL=$((FAIL + 1))
    fi
}

assert_output_contains() {
    local desc="$1"
    shift
    local pattern="$1"
    shift

    local output
    output=$("$@" 2>&1) || true
    if echo "$output" | grep -qF -- "$pattern"; then
        echo "  PASS: $desc"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $desc (expected output to contain '$pattern')"
        echo "        got: $output"
        FAIL=$((FAIL + 1))
    fi
}

assert_output_line_count() {
    local desc="$1"
    local expected="$2"
    shift 2

    local output
    output=$("$@" 2>&1) || true
    local count
    count=$(echo "$output" | grep -c '^\s*\[' || true)
    if [[ "$count" -eq "$expected" ]]; then
        echo "  PASS: $desc"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $desc (expected $expected numbered lines, got $count)"
        echo "        got: $output"
        FAIL=$((FAIL + 1))
    fi
}

# -------------------------------------------------------------------
echo "=== Usage / Help ==="

assert_exit 0 "help flag shows usage" "$BIN" --help
assert_exit 0 "no args shows usage" "$BIN"
assert_output_contains "help mentions --over" "--over" "$BIN" --help

# -------------------------------------------------------------------
echo ""
echo "=== show command ==="

assert_output_contains "show single axis" "3 combinations" "$BIN" show --over ver=1,2,3
assert_output_line_count "show single axis lists 3 entries" 3 "$BIN" show --over ver=1,2,3
assert_output_contains "show multi-axis" "6 combinations" "$BIN" show --over x=a,b --over y=1,2,3
assert_output_line_count "show multi-axis lists 6 entries" 6 "$BIN" show --over x=a,b --over y=1,2,3
assert_exit 1 "show without --over fails" "$BIN" show

# -------------------------------------------------------------------
echo ""
echo "=== run command ==="

TMPDIR_RUN=$(mktemp -d)
trap 'rm -rf "$TMPDIR_RUN"' EXIT

assert_exit 0 "run passes on successful command" "$BIN" run "true" --over v=1,2 --output "$TMPDIR_RUN/r1"
assert_output_contains "run reports all passed" "2/2 passed" "$BIN" run "true" --over v=1,2 --output "$TMPDIR_RUN/r2"

assert_exit 1 "run fails on failing command" "$BIN" run "false" --over v=1,2 --output "$TMPDIR_RUN/r3"

# Test variable interpolation
assert_exit 0 "run with interpolation" "$BIN" run "echo {val}" --over val=hello,world --output "$TMPDIR_RUN/r4"

# Verify log files created
assert_output_contains "run creates log files" "val=hello" "$BIN" run "echo {val}" --over val=hello --output "$TMPDIR_RUN/r5"
if [[ -f "$TMPDIR_RUN/r5/val=hello.log" ]]; then
    echo "  PASS: log file created for combination"
    PASS=$((PASS + 1))
else
    echo "  FAIL: expected log file $TMPDIR_RUN/r5/val=hello.log"
    FAIL=$((FAIL + 1))
fi

# Test MATRIX_ env variable export
# shellcheck disable=SC2016
echo '#!/bin/bash
echo "VAL=$MATRIX_DB"' > "$TMPDIR_RUN/check_env.sh"
chmod +x "$TMPDIR_RUN/check_env.sh"
"$BIN" run "$TMPDIR_RUN/check_env.sh" --over db=postgres --output "$TMPDIR_RUN/r6" > /dev/null 2>&1 || true
if [[ -f "$TMPDIR_RUN/r6/db=postgres.log" ]] && grep -q "VAL=postgres" "$TMPDIR_RUN/r6/db=postgres.log"; then
    echo "  PASS: MATRIX_ env variable exported correctly"
    PASS=$((PASS + 1))
else
    echo "  FAIL: MATRIX_DB not exported correctly"
    FAIL=$((FAIL + 1))
fi

# Test --fail-fast
assert_exit 1 "fail-fast stops on first failure" "$BIN" run "false" --over v=1,2,3,4 --parallel 1 --fail-fast --output "$TMPDIR_RUN/r7"

# -------------------------------------------------------------------
echo ""
echo "=== run validation ==="

assert_exit 1 "run without command fails" "$BIN" run --over v=1,2 --output "$TMPDIR_RUN/r8"
assert_exit 1 "run without --over fails" "$BIN" run "echo hi" --output "$TMPDIR_RUN/r9"

# -------------------------------------------------------------------
echo ""
echo "=== status command ==="

"$BIN" run "true" --over v=a,b --output "$TMPDIR_RUN/r10" > /dev/null 2>&1 || true
FLEDGE_MATRIX_OUTPUT="$TMPDIR_RUN/r10" assert_output_contains "status shows pass" "PASS" "$BIN" status

"$BIN" run "false" --over v=a --output "$TMPDIR_RUN/r11" > /dev/null 2>&1 || true
FLEDGE_MATRIX_OUTPUT="$TMPDIR_RUN/r11" assert_output_contains "status shows fail" "FAIL" "$BIN" status

# -------------------------------------------------------------------
echo ""
echo "=== Results ==="
TOTAL=$((PASS + FAIL))
echo "$PASS/$TOTAL passed"
if [[ $FAIL -gt 0 ]]; then
    exit 1
fi
