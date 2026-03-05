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

if [[ -z "${CDE_INTEGRATION_MODEL_MOMD:-}" ]]; then
  CDE_INTEGRATION_MODEL_MOMD="$(bash "$ROOT_DIR/Scripts/compile-integration-model.sh" | tail -n 1)"
  export CDE_INTEGRATION_MODEL_MOMD
fi

cd "$ROOT_DIR"
swift test --filter IntegrationModelTests "$@"
