#!/usr/bin/env bash
# Enable Bitrise Build Cache for this job (not timed). $1 = xcode | bazel.
# Build Hub runners authenticate to the workspace's cache without a token; elsewhere set
# BITRISE_BUILD_CACHE_AUTH_TOKEN and BITRISE_BUILD_CACHE_WORKSPACE_ID.
set -euo pipefail
tool="$1"; BIN="$RUNNER_TEMP/bbc-bin"; mkdir -p "$BIN"
curl --retry 5 -sSfL 'https://raw.githubusercontent.com/bitrise-io/bitrise-build-cache-cli/main/install/installer.sh' | sh -s -- -b "$BIN" -d
BBC="$BIN/bitrise-build-cache"
VER=$("$BBC" --version 2>/dev/null | head -1 || echo unknown); echo "Bitrise Build Cache CLI: $VER"
case "$tool" in
  xcode)
    "$BBC" activate xcode --cache --cache-push
    W="$HOME/.bitrise-xcelerate/bin"
    [ -x "$W/xcodebuild" ] || { echo "❌ xcodebuild wrapper not found in $W"; ls -la "$HOME/.bitrise-xcelerate" || true; exit 1; }
    echo "$W" >> "$GITHUB_PATH"
    echo "xcodebuild now resolves to $W/xcodebuild for later steps" ;;
  bazel)
    "$BBC" activate bazel --cache --cache-push
    echo "--- ~/.bazelrc"; cat "$HOME/.bazelrc" ;;
  *) echo "unknown tool $tool"; exit 2 ;;
esac
{ echo "BENCH_BUILD_CACHE=$tool"; echo "BENCH_BBC_VERSION=$VER"; echo "BBC=$BBC"; } >> "$GITHUB_ENV"
