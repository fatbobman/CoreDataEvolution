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
ORIGINAL_FIXTURE_DIR="$FIXTURE_DIR"
ORIGINAL_CONFIG_PATH="$CONFIG_PATH"
APP_TARGET="${CDE_GENERATED_FLOW_TARGET:-GeneratedFlowApp}"
DEPENDENCY_MODE="${CDE_GENERATED_FLOW_DEPENDENCY_MODE:-path}"
DEPENDENCY_REF="${CDE_GENERATED_FLOW_REF:-}"
REPO_URL="${CDE_GENERATED_FLOW_REPO_URL:-$(git -C "$ROOT_DIR" config --get remote.origin.url || true)}"
RUN_APP=true
SKIP_GENERATE=false
SKIP_VALIDATE=false
SKIP_BUILD=false
TEMP_FIXTURE_DIR=""

CACHE_ROOT="$ROOT_DIR/.cache/generated-flow"
mkdir -p "$CACHE_ROOT/clang" "$CACHE_ROOT/swiftpm"
export CLANG_MODULE_CACHE_PATH="$CACHE_ROOT/clang"
export SWIFT_MODULECACHE_PATH="$CACHE_ROOT/clang"
export SWIFTPM_CUSTOM_CACHE_DIR="$CACHE_ROOT/swiftpm"

usage() {
  cat <<EOF2
Usage:
  bash Scripts/test-generated-flow.sh [options]

Runs the generated-flow fixture as a black-box style integration check:
  1. build cde-tool
  2. generate source into the selected fixture package
  3. validate conformance and exact
  4. build the external executable target
  5. run the executable smoke flow

Options:
  --skip-generate            Skip model generation.
  --skip-validate            Skip conformance/exact validation.
  --skip-build               Skip building the external executable target.
  --skip-run                 Skip running the external executable target.
  --dependency-mode <mode>   Fixture dependency source: path/tag/branch/revision.
  --ref <value>              Tag/branch/revision value for non-path dependency modes.
  --repo-url <url>           Repository URL used for non-path dependency modes.
  -h, --help                 Show this help.

Environment overrides:
  CDE_GENERATED_FLOW_FIXTURE          Path to fixture package (default: Integration/GeneratedFlowFixture)
  CDE_GENERATED_FLOW_CONFIG           Path to fixture config file (default: <fixture>/cde-tool.json)
  CDE_GENERATED_FLOW_TARGET           Executable target to build/run (default: GeneratedFlowApp)
  CDE_GENERATED_FLOW_DEPENDENCY_MODE  Fixture dependency source: path/tag/branch/revision
  CDE_GENERATED_FLOW_REF              Tag/branch/revision value for non-path dependency modes
  CDE_GENERATED_FLOW_REPO_URL         Repository URL used for non-path dependency modes

Notes:
  - path mode validates the current workspace source via the checked-in fixture package.
  - tag/branch/revision modes copy the fixture to a temp directory and rewrite only the
    fixture's Package.swift dependency, leaving the tracked fixture files untouched.
EOF2
}

cleanup() {
  if [[ -n "$TEMP_FIXTURE_DIR" && -d "$TEMP_FIXTURE_DIR" ]]; then
    rm -rf "$TEMP_FIXTURE_DIR"
  fi
}

rewrite_fixture_dependency() {
  local package_file="$1"
  local replacement

  case "$DEPENDENCY_MODE" in
    path)
      return 0
      ;;
    tag)
      replacement=".package(url: \"$REPO_URL\", exact: \"$DEPENDENCY_REF\")"
      ;;
    branch)
      replacement=".package(url: \"$REPO_URL\", branch: \"$DEPENDENCY_REF\")"
      ;;
    revision)
      replacement=".package(url: \"$REPO_URL\", revision: \"$DEPENDENCY_REF\")"
      ;;
    *)
      echo "Unsupported dependency mode: $DEPENDENCY_MODE" >&2
      exit 1
      ;;
  esac

  perl -0pi -e \
    's/\.package\(path: "\.\.\/\.\."\)/$ENV{CDE_FIXTURE_DEPENDENCY_REPLACEMENT}/g' \
    "$package_file"
}

prepare_fixture() {
  if [[ "$DEPENDENCY_MODE" == "path" ]]; then
    return 0
  fi

  if [[ -z "$DEPENDENCY_REF" ]]; then
    echo "--ref is required when --dependency-mode is tag, branch, or revision." >&2
    exit 1
  fi

  if [[ -z "$REPO_URL" ]]; then
    echo "--repo-url is required when remote.origin.url is unavailable." >&2
    exit 1
  fi

  TEMP_FIXTURE_DIR="$(mktemp -d "${TMPDIR:-/tmp}/cde-generated-flow.XXXXXX")"
  trap cleanup EXIT

  cp -R "$FIXTURE_DIR/." "$TEMP_FIXTURE_DIR"
  export CDE_FIXTURE_DEPENDENCY_REPLACEMENT
  case "$DEPENDENCY_MODE" in
    tag)
      CDE_FIXTURE_DEPENDENCY_REPLACEMENT=".package(url: \"$REPO_URL\", exact: \"$DEPENDENCY_REF\")"
      ;;
    branch)
      CDE_FIXTURE_DEPENDENCY_REPLACEMENT=".package(url: \"$REPO_URL\", branch: \"$DEPENDENCY_REF\")"
      ;;
    revision)
      CDE_FIXTURE_DEPENDENCY_REPLACEMENT=".package(url: \"$REPO_URL\", revision: \"$DEPENDENCY_REF\")"
      ;;
  esac
  rewrite_fixture_dependency "$TEMP_FIXTURE_DIR/Package.swift"

  FIXTURE_DIR="$TEMP_FIXTURE_DIR"
  if [[ "$ORIGINAL_CONFIG_PATH" == "$ORIGINAL_FIXTURE_DIR/"* ]]; then
    CONFIG_PATH="$FIXTURE_DIR/${ORIGINAL_CONFIG_PATH#$ORIGINAL_FIXTURE_DIR/}"
  else
    CONFIG_PATH="$ORIGINAL_CONFIG_PATH"
  fi
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
    --dependency-mode)
      DEPENDENCY_MODE="${2:-}"
      shift 2
      ;;
    --ref)
      DEPENDENCY_REF="${2:-}"
      shift 2
      ;;
    --repo-url)
      REPO_URL="${2:-}"
      shift 2
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

prepare_fixture

echo "Fixture: $FIXTURE_DIR"
echo "Config:  $CONFIG_PATH"
echo "Mode:    $DEPENDENCY_MODE"
if [[ "$DEPENDENCY_MODE" != "path" ]]; then
  echo "Ref:     $DEPENDENCY_REF"
  echo "Repo:    $REPO_URL"
fi

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

  echo ">>> Building external generated product"
  swift build --package-path "$FIXTURE_DIR" --product "$APP_TARGET"
fi

if [[ "$RUN_APP" == true ]]; then
  BIN_PATH="$(swift build --package-path "$FIXTURE_DIR" --show-bin-path)"
  APP_BINARY="$BIN_PATH/$APP_TARGET"

  if [[ ! -x "$APP_BINARY" ]]; then
    echo "Expected built app at $APP_BINARY, but it was not found or is not executable." >&2
    exit 1
  fi

  echo ">>> Running external generated flow"
  "$APP_BINARY"
fi
