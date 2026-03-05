#!/usr/bin/env bash
#
#  ------------------------------------------------
#  Original project: CoreDataEvolution
#  Created on 2026/3/5 by Fatbobman(东坡肘子)
#  X: @fatbobman
#  Mastodon: @fatbobman@mastodon.social
#  GitHub: @fatbobman
#  Blog: https://fatbobman.com
#  ------------------------------------------------
#  Copyright © 2024-present Fatbobman. All rights reserved.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEFAULT_SOURCE_MODEL_DIR="$ROOT_DIR/Models/Integration/CoreDataEvolutionIntegrationModel.xcdatamodeld"
DEFAULT_OUTPUT_DIR="$ROOT_DIR/.build/cde-models/CoreDataEvolutionIntegrationModel.momd"

SOURCE_MODEL_DIR="${1:-${CDE_INTEGRATION_MODEL_SOURCE:-$DEFAULT_SOURCE_MODEL_DIR}}"
OUTPUT_DIR="${2:-${CDE_INTEGRATION_MODEL_OUTPUT:-$DEFAULT_OUTPUT_DIR}}"

if [[ -n "${CDE_MOMC_BIN:-}" ]]; then
  MOMC_BIN="$CDE_MOMC_BIN"
elif command -v xcrun >/dev/null 2>&1; then
  MOMC_BIN="$(xcrun --find momc)"
elif command -v momc >/dev/null 2>&1; then
  MOMC_BIN="$(command -v momc)"
else
  echo "error: unable to locate 'momc'. Set CDE_MOMC_BIN or install Xcode command line tools." >&2
  exit 1
fi

if [[ ! -d "$SOURCE_MODEL_DIR" ]]; then
  echo "error: source model not found: $SOURCE_MODEL_DIR" >&2
  exit 1
fi

mkdir -p "$(dirname "$OUTPUT_DIR")"
rm -rf "$OUTPUT_DIR"

"$MOMC_BIN" "$SOURCE_MODEL_DIR" "$OUTPUT_DIR" >&2

echo "$OUTPUT_DIR"
