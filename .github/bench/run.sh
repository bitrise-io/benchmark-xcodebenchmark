#!/usr/bin/env bash
# XcodeBenchmark clean build via benchmark.sh (port of Bitrise _xcodebenchmark).
set -eo pipefail
source "$(dirname "$0")/lib.sh"
cd "$GITHUB_WORKSPACE"
LOGS="$BENCH_OUT/logs"; mkdir -p "$LOGS"
echo "project,metric_key,machine_key,run,duration_sec" > "$BENCH_OUT/results.csv"
: > "$BENCH_OUT/durations.txt"
for i in $(seq 1 $(( WARMUP_RUNS + BENCHMARK_RUNS ))); do
  run_label "$i"; echo "=== XcodeBenchmark $LABEL ==="
  if ! sh benchmark.sh > "$LOGS/$LABEL.log" 2>&1; then tail -n 60 "$LOGS/$LABEL.log"; echo "benchmark.sh failed on $LABEL"; exit 1; fi
  tail -n 6 "$LOGS/$LABEL.log"
  D=$(sed -n 's/^Build Time: [0-9]* sec (\([0-9.]*\) sec)$/\1/p' "$LOGS/$LABEL.log")
  [ -n "$D" ] || { echo "Could not parse duration for $LABEL"; exit 1; }
  echo "${BENCHMARK_PROJECT},clean_build,${MACHINE_KEY},${LABEL},${D}" >> "$BENCH_OUT/results.csv"
  if [ "$MEASURED" = 1 ]; then echo "$D" >> "$BENCH_OUT/durations.txt"; fi
done
cat > "$BENCH_OUT/summary.json" <<JSON
{
$(summary_common),
  "benchmark_revision": "$(source_rev)",
  "clean_build": $(stats "$BENCH_OUT/durations.txt")
}
JSON
(cd "$BENCH_OUT" && rm -f durations.txt)
finish
