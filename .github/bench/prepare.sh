#!/usr/bin/env bash
set -eo pipefail
cd "$GITHUB_WORKSPACE"
sh scripts/system-info.sh || true
