#!/usr/bin/env bash

# Compile a real consumer below Observation's deployment baseline; macro snapshots alone cannot
# catch SDK availability errors. On Apple silicon, the compiler uses macOS 11+ as its target floor.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FIXTURE_DIR="$ROOT_DIR/Integration/ModelActorAvailabilityFixture"
CACHE_ROOT="$ROOT_DIR/.cache/model-actor-availability"
mkdir -p "$CACHE_ROOT/clang" "$CACHE_ROOT/swiftpm"
export CLANG_MODULE_CACHE_PATH="$CACHE_ROOT/clang"
export SWIFT_MODULECACHE_PATH="$CACHE_ROOT/clang"
export SWIFTPM_CUSTOM_CACHE_DIR="$CACHE_ROOT/swiftpm"

swift build --package-path "$FIXTURE_DIR" --product ModelActorAvailabilityApp
BIN_PATH="$(swift build --package-path "$FIXTURE_DIR" --show-bin-path)"
env "com.apple.CoreData.ConcurrencyDebug=1" "$BIN_PATH/ModelActorAvailabilityApp"
