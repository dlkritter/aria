#!/usr/bin/env bash
set -e

print_usage() {
    echo "Usage: $0 <command> <bench>"
    echo "command: bench, micro, perf, time, valgrind"
    echo "bench: Name or partial name of the benchmark to run"
}

COMMAND=$1
BENCH=$2

if [ -z "$COMMAND" ]; then
    print_usage
    exit 1
fi

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ARIA_BUILD_CONFIG="${ARIA_BUILD_CONFIG:-release}"
CPU_AFFINITY_MASK="${CPU_AFFINITY_MASK:-0x1}"
if [ -z "${ARIA_EXECUTABLE:-}" ]; then
    cargo build --profile "$ARIA_BUILD_CONFIG" --bin aria
    TARGET_DIR=$(cd "$SELF_DIR" && cargo metadata --format-version 1 --no-deps 2>/dev/null | jq -r '.target_directory // empty' 2>/dev/null || true)
    if [ -z "$TARGET_DIR" ]; then
        TARGET_DIR="${SELF_DIR}/../target"
    fi
    ARIA_EXECUTABLE="${TARGET_DIR}/${ARIA_BUILD_CONFIG}/aria"
fi
export ARIA_EXECUTABLE
ARIA_LIB_DIR="${ARIA_LIB_DIR:-${SELF_DIR}/lib:${SELF_DIR}/lib-test}"

export ARIA_LIB_DIR="$ARIA_LIB_DIR"

if [ "$COMMAND" = "bench" ]; then
    cargo bench --profile "$ARIA_BUILD_CONFIG" --package vm-lib "$BENCH"
elif [ "$COMMAND" = "micro" ]; then
    if [ ! -f "$BENCH" ]; then
        BENCH="${SELF_DIR}/microbenchmarks/${BENCH}.aria"
    fi
    ARIA_LIB_DIR="${ARIA_LIB_DIR}:${SELF_DIR}/microbenchmarks"
    export ARIA_LIB_DIR
    if command -v taskset >/dev/null 2>&1; then
        exec taskset "$CPU_AFFINITY_MASK" "${ARIA_EXECUTABLE}" "$BENCH" "${@:3}"
    else
        exec "${ARIA_EXECUTABLE}" "$BENCH" "${@:3}"
    fi
else
    OUTPUT=$(cargo bench --no-run --profile "$ARIA_BUILD_CONFIG" --package vm-lib "$BENCH" 2>&1)
    echo "$OUTPUT"
    EXECUTABLE_PATH=$(echo "$OUTPUT" | grep "^  Executable" | tail -n1 | awk '{gsub(/[()]/,"",$NF); print $NF}')

    case "$COMMAND" in
        perf)
            echo "Running with perf..."
            perf record -g "$EXECUTABLE_PATH" "$BENCH"
            ;;
        valgrind)
            echo "Running with Valgrind Callgrind..."
            ulimit -n 4096
            valgrind --tool=callgrind "$EXECUTABLE_PATH" "$BENCH"
            ;;
        time)
            echo "Running with time..."
            time "$EXECUTABLE_PATH" "$BENCH"
            ;;
        *)
            echo "Invalid command"
            print_usage
            exit 1
            ;;
    esac
fi