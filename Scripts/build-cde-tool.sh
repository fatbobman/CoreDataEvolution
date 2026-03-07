#!/usr/bin/env bash

#  ------------------------------------------------
#  Original project: CoreDataEvolution
#  Created on 2026/3/7 by Fatbobman(东坡肘子)
#  X: @fatbobman
#  Mastodon: @fatbobman@mastodon.social
#  GitHub: @fatbobman
#  Blog: https://fatbobman.com
#  ------------------------------------------------
#  Copyright © 2024-present Fatbobman. All rights reserved.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
METADATA_FILE="$ROOT_DIR/Sources/CDETool/Support/ToolBuildMetadata.swift"
COPY_TO=""
FORCE=false

usage() {
  cat <<'EOF'
Usage:
  bash Scripts/build-cde-tool.sh [--copy-to <dir>] [--force]

Builds cde-tool in release mode.

Options:
  --copy-to <dir>  Copy the built cde-tool binary into the target directory.
  --force          Overwrite an existing copied binary.
  -h, --help       Show this help.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --copy-to)
      COPY_TO="${2:-}"
      shift 2
      ;;
    --force)
      FORCE=true
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

if [[ -n "$COPY_TO" ]] && [[ "$COPY_TO" != /* ]]; then
  COPY_TO="$ROOT_DIR/$COPY_TO"
fi

cd "$ROOT_DIR"

CACHE_ROOT="$ROOT_DIR/.cache/cde-tool-build"
mkdir -p "$CACHE_ROOT/clang" "$CACHE_ROOT/swiftpm"
export CLANG_MODULE_CACHE_PATH="$CACHE_ROOT/clang"
export SWIFT_MODULECACHE_PATH="$CACHE_ROOT/clang"
export SWIFTPM_CUSTOM_CACHE_DIR="$CACHE_ROOT/swiftpm"

GIT_TAG="$(git describe --tags --exact-match 2>/dev/null || true)"
GIT_DESCRIBE="$(git describe --tags --always --dirty 2>/dev/null || echo "unreleased")"
GIT_COMMIT="$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")"

if git status --porcelain --untracked-files=no >/dev/null 2>&1; then
  if [[ -n "$(git status --porcelain --untracked-files=no)" ]]; then
    IS_DIRTY=true
  else
    IS_DIRTY=false
  fi
else
  IS_DIRTY=true
fi

VERSION="$GIT_DESCRIBE"
if [[ -n "$GIT_TAG" ]]; then
  VERSION="$GIT_TAG"
fi

BACKUP_FILE="$(mktemp)"
cp "$METADATA_FILE" "$BACKUP_FILE"

cleanup() {
  cp "$BACKUP_FILE" "$METADATA_FILE"
  rm -f "$BACKUP_FILE"
}

trap cleanup EXIT

cat > "$METADATA_FILE" <<EOF
//
//  ------------------------------------------------
//  Original project: CoreDataEvolution
//  Created on 2026/3/7 by Fatbobman(东坡肘子)
//  X: @fatbobman
//  Mastodon: @fatbobman@mastodon.social
//  GitHub: @fatbobman
//  Blog: https://fatbobman.com
//  ------------------------------------------------
//  Copyright © 2024-present Fatbobman. All rights reserved.

/// Build metadata injected by Scripts/build-cde-tool.sh for release-style cde-tool binaries.
enum ToolBuildMetadata {
  static let version = "$(printf '%s' "$VERSION")"
  static let gitTag = "$(printf '%s' "${GIT_TAG:-unreleased}")"
  static let gitCommit = "$(printf '%s' "$GIT_COMMIT")"
  static let gitDescribe = "$(printf '%s' "$GIT_DESCRIBE")"
  static let isDirty = $IS_DIRTY
}
EOF

swift build -c release --product cde-tool
BIN_PATH="$(swift build -c release --show-bin-path)/cde-tool"

echo "Built cde-tool:"
echo "  $BIN_PATH"
echo "Version:"
echo "  $VERSION"
echo "Commit:"
echo "  $GIT_COMMIT"
echo "Dirty:"
echo "  $IS_DIRTY"

if [[ -n "$COPY_TO" ]]; then
  mkdir -p "$COPY_TO"
  DEST_PATH="$COPY_TO/cde-tool"
  if [[ -e "$DEST_PATH" && "$FORCE" != true ]]; then
    echo "Refusing to overwrite existing binary at: $DEST_PATH" >&2
    echo "Re-run with --force to replace it." >&2
    exit 1
  fi

  cp "$BIN_PATH" "$DEST_PATH"
  chmod +x "$DEST_PATH"
  echo "Copied to:"
  echo "  $DEST_PATH"
fi
