#!/usr/bin/env bash

#  ------------------------------------------------
#  Original project: CoreDataEvolution
#  Created on 2026/3/10 by Fatbobman(东坡肘子)
#  X: @fatbobman
#  Mastodon: @fatbobman@mastodon.social
#  GitHub: @fatbobman
#  Blog: https://fatbobman.com
#  ------------------------------------------------
#  Copyright © 2024-present Fatbobman. All rights reserved.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FILTER=""
PARALLEL=true
SQL_DEBUG=false
EXTRA_SWIFT_ARGS=()

usage() {
  cat <<'EOF'
Usage:
  bash Scripts/run-tests.sh [options]

Runs swift test with Core Data concurrency checking enabled
(-com.apple.CoreData.ConcurrencyDebug 1).

Options:
  --filter <pattern>   Forward --filter to swift test (run matching tests only).
  --no-parallel        Disable parallel test execution (--no-parallel).
  --sql-debug          Also enable -com.apple.CoreData.SQLDebug 1 (verbose).
  -h, --help           Show this help.

Examples:
  bash Scripts/run-tests.sh
  bash Scripts/run-tests.sh --filter ModelActorTests
  bash Scripts/run-tests.sh --no-parallel --sql-debug
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --filter)
      FILTER="${2:-}"
      shift 2
      ;;
    --no-parallel)
      PARALLEL=false
      shift
      ;;
    --sql-debug)
      SQL_DEBUG=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

cd "$ROOT_DIR"

CACHE_ROOT="$ROOT_DIR/.cache/test"
mkdir -p "$CACHE_ROOT/clang" "$CACHE_ROOT/swiftpm"
export CLANG_MODULE_CACHE_PATH="$CACHE_ROOT/clang"
export SWIFT_MODULECACHE_PATH="$CACHE_ROOT/clang"
export SWIFTPM_CUSTOM_CACHE_DIR="$CACHE_ROOT/swiftpm"

if [[ -n "$FILTER" ]]; then
  EXTRA_SWIFT_ARGS+=(--filter "$FILTER")
fi

if [[ "$PARALLEL" != true ]]; then
  EXTRA_SWIFT_ARGS+=(--no-parallel)
fi

# -com.apple.CoreData.ConcurrencyDebug 1 enables Core Data's concurrency
# violation checker, which crashes on cross-context object access and
# context use from the wrong thread. Always on in this script.
# Core Data debug flags are injected via env so they work regardless of
# swift test version, test runner, or CI environment.
# Keys with dots cannot be set with bash export; use env instead.
ENV_ARGS=("com.apple.CoreData.ConcurrencyDebug=1")

if [[ "$SQL_DEBUG" == true ]]; then
  ENV_ARGS+=("com.apple.CoreData.SQLDebug=1")
fi

echo "env ${ENV_ARGS[*]} swift test ${EXTRA_SWIFT_ARGS[*]+"${EXTRA_SWIFT_ARGS[*]}"}"
echo ""

env "${ENV_ARGS[@]}" swift test "${EXTRA_SWIFT_ARGS[@]+"${EXTRA_SWIFT_ARGS[@]}"}"
