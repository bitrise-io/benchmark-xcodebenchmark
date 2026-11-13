#!/usr/bin/env bash
# Shared helpers for the GitHub Actions benchmark workflows (port of the Bitrise standard-v3 helpers).
# BENCH_OUT, MACHINE_KEY, BENCHMARK_PROJECT, WARMUP_RUNS, BENCHMARK_RUNS come from the workflow env.

now() { python3 -c 'import time; print(time.time())'; }

# Hardware / toolchain info, also written to $BENCH_OUT/system-info.txt
sysinfo() {
  mkdir -p "$BENCH_OUT"
  {
    echo "machine_key: ${MACHINE_KEY:-unknown}"
    echo "runner_name: ${RUNNER_NAME:-unknown}"
    echo "chip: $(sysctl -n machdep.cpu.brand_string)"
    echo "logical_cpus: $(sysctl -n hw.logicalcpu)"
    echo "perf_cores: $(sysctl -n hw.perflevel0.physicalcpu 2>/dev/null || echo n/a)"
    echo "eff_cores: $(sysctl -n hw.perflevel1.physicalcpu 2>/dev/null || echo n/a)"
    echo "memory_gb: $(( $(sysctl -n hw.memsize) / 1073741824 ))"
    echo "macOS: $(sw_vers -productVersion) ($(sw_vers -buildVersion))"
    echo "Xcode: $(xcodebuild -version 2>/dev/null | tr '\n' ' ')"
    df -h / | tail -n 1
  } | tee "$BENCH_OUT/system-info.txt"
}

# Xcode-reported seconds from an xcodebuild log, empty if not found
xc_seconds() { sed -n -E 's/^\*\* [A-Z -]+ (SUCCEEDED|FAILED) \*\* \[([0-9.]+) sec\].*$/\2/p' "$1" | tail -1; }

# $1 = file with one value per line -> JSON object
stats() {
  sort -n "$1" | awk '{ a[NR]=$1; s+=$1 }
    END { if (NR == 0) { printf "null"; exit }
          med = (NR % 2) ? a[(NR+1)/2] : (a[NR/2] + a[NR/2+1]) / 2
          printf "{\"median_sec\": %.3f, \"mean_sec\": %.3f, \"min_sec\": %.3f, \"max_sec\": %.3f}", med, s/NR, a[1], a[NR] }'
}

# Run label for iteration $1 (sets LABEL and MEASURED)
run_label() {
  if [ "$1" -le "$WARMUP_RUNS" ]; then LABEL="warmup$1"; MEASURED=0; else LABEL="run$(( $1 - WARMUP_RUNS ))"; MEASURED=1; fi
}

# Commit of the benchmarked source: SOURCE_REV is written by setup.sh (the mirrored default-branch tip,
# before the .github/ commit was added). Falls back to HEAD.
source_rev() {
  local f; f="$(dirname "${BASH_SOURCE[0]}")/SOURCE_REV"
  if [ -s "$f" ]; then cat "$f"; else git rev-parse HEAD; fi
}

# Common summary fields (no trailing comma)
summary_common() {
  cat <<JSON
  "project": "${BENCHMARK_PROJECT}",
  "method_version": "${METHOD_VERSION:-gha-v1}",
  "machine_key": "${MACHINE_KEY}",
  "runner_name": "${RUNNER_NAME:-}",
  "xcode": "$(xcodebuild -version 2>/dev/null | awk '/^Xcode /{print $2}')",
  "build_cache": "${BENCH_BUILD_CACHE:-off}",
  "build_cache_cli": "${BENCH_BBC_VERSION:-}",
  "warmup_runs": ${WARMUP_RUNS},
  "runs": ${BENCHMARK_RUNS},
  "github_run": "${GITHUB_SERVER_URL:-}/${GITHUB_REPOSITORY:-}/actions/runs/${GITHUB_RUN_ID:-}"
JSON
}

finish() { # zip logs, show summary
  (cd "$BENCH_OUT" && [ -d logs ] && zip -qr logs.zip logs && rm -rf logs) || true
  cat "$BENCH_OUT/summary.json"
  if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
    { echo "### ${BENCHMARK_PROJECT} on \`${MACHINE_KEY}\`"; echo '```json'; cat "$BENCH_OUT/summary.json"; echo '```'; } >> "$GITHUB_STEP_SUMMARY"
  fi
}
