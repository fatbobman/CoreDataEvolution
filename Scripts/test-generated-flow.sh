#!/usr/bin/env bash

#  ------------------------------------------------
#  Original project: CoreDataEvolution
#  Created on 2026/3/8 by Fatbobman(东坡肘子)
#  X: @fatbobman
#  Mastodon: @fatbobman@mastodon.social
#  GitHub: @fatbobman
#  Blog: https://fatbobman.com
#  ------------------------------------------------
#  Copyright © 2024-present Fatbobman. All rights reserved.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FIXTURE_DIR="${CDE_GENERATED_FLOW_FIXTURE:-$ROOT_DIR/Integration/GeneratedFlowFixture}"
CONFIG_PATH="${CDE_GENERATED_FLOW_CONFIG:-$FIXTURE_DIR/cde-tool.json}"
APP_TARGET="${CDE_GENERATED_FLOW_TARGET:-GeneratedFlowApp}"
RUN_APP=true
SKIP_GENERATE=false
SKIP_VALIDATE=false
SKIP_BUILD=false

CACHE_ROOT="$ROOT_DIR/.cache/generated-flow"
mkdir -p "$CACHE_ROOT/clang" "$CACHE_ROOT/swiftpm"
export CLANG_MODULE_CACHE_PATH="$CACHE_ROOT/clang"
export SWIFT_MODULECACHE_PATH="$CACHE_ROOT/clang"
export SWIFTPM_CUSTOM_CACHE_DIR="$CACHE_ROOT/swiftpm"

usage() {
  cat <<EOF2
Usage:
  bash Scripts/test-generated-flow.sh [--skip-generate] [--skip-validate] [--skip-build] [--skip-run]

Runs the generated-flow fixture as a black-box style integration check:
  1. build cde-tool
  2. generate source into Integration/GeneratedFlowFixture
  3. validate conformance and exact
  4. build the external executable target
  5. run the executable smoke flow

Environment overrides:
  CDE_GENERATED_FLOW_FIXTURE  Path to fixture package (default: Integration/GeneratedFlowFixture)
  CDE_GENERATED_FLOW_CONFIG   Path to fixture config file (default: <fixture>/cde-tool.json)
  CDE_GENERATED_FLOW_TARGET   Executable target to build/run (default: GeneratedFlowApp)
EOF2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-generate)
      SKIP_GENERATE=true
      shift
      ;;
    --skip-validate)
      SKIP_VALIDATE=true
      shift
      ;;
    --skip-build)
      SKIP_BUILD=true
      shift
      ;;
    --skip-run)
      RUN_APP=false
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

echo "Fixture: $FIXTURE_DIR"
echo "Config:  $CONFIG_PATH"

echo ">>> Building cde-tool"
swift build --product cde-tool

if [[ "$SKIP_GENERATE" != true ]]; then
  echo ">>> Generating models"
  swift run --skip-build cde-tool generate --config "$CONFIG_PATH" --overwrite all
fi

if [[ "$SKIP_VALIDATE" != true ]]; then
  echo ">>> Validating generated source (conformance)"
  swift run --skip-build cde-tool validate --config "$CONFIG_PATH" --level conformance

  echo ">>> Validating generated source (exact)"
  swift run --skip-build cde-tool validate --config "$CONFIG_PATH" --level exact
fi

if [[ "$SKIP_BUILD" != true ]]; then
  echo ">>> Cleaning external fixture build artifacts"
  rm -rf "$FIXTURE_DIR/.build"

  echo ">>> Building external generated target"
  swift build --package-path "$FIXTURE_DIR" --target "$APP_TARGET"
fi

if [[ "$RUN_APP" == true ]]; then
  echo ">>> Running external generated flow"
  swift run --package-path "$FIXTURE_DIR" "$APP_TARGET"
fi
