#!/usr/bin/env bash
# benchmark.sh - Performance and compression ratio benchmarks for pdf-deflyt
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export ROOT
export BUILD_DIR="$ROOT/tests/build-bench"
export ASSETS_DIR="$ROOT/tests/assets-bench"

# Configuration
RUNS=${PDF_DEFLYT_BENCH_RUNS:-3}  # Number of runs per test
VERBOSE=${PDF_DEFLYT_BENCH_VERBOSE:-0}

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() { echo -e "${BLUE}[BENCH]${NC} $*"; }
success() { echo -e "${GREEN}✓${NC} $*"; }
info() { echo -e "${YELLOW}→${NC} $*"; }

# Setup
setup_bench() {
  log "Setting up benchmark environment..."
  rm -rf "$BUILD_DIR" "$ASSETS_DIR"
  mkdir -p "$BUILD_DIR" "$ASSETS_DIR"

  # Create test fixtures if not already present
  if [[ ! -f "$ROOT/tests/assets/mixed.pdf" ]]; then
    log "Creating test fixtures..."
    "$ROOT/tests/fixtures.sh" >/dev/null 2>&1 || true
  fi

  # Copy test fixtures to benchmark assets
  if [[ -d "$ROOT/tests/assets" ]]; then
    cp -r "$ROOT/tests/assets"/* "$ASSETS_DIR/" 2>/dev/null || true
  fi

  success "Benchmark environment ready"
}

# Get file size in bytes
size_of() {
  stat -f%z "$1" 2>/dev/null || stat -c%s "$1" 2>/dev/null || echo 0
}

# Format bytes to human readable
fmt_bytes() {
  local b="$1"
  awk -v b="$b" 'BEGIN{
    if (b<1024){printf "%d B", b; exit}
    kb=b/1024; if (kb<1024){printf "%.1f KB", kb; exit}
    mb=kb/1024; if (mb<1024){printf "%.2f MB", mb; exit}
    gb=mb/1024; printf "%.2f GB", gb
  }'
}

# Benchmark a single preset on a single file
bench_one() {
  local input="$1"
  local preset="$2"
  local output="$BUILD_DIR/bench_$(basename "$input" .pdf)_${preset}.pdf"

  local input_size=$(size_of "$input")

  # Measure time (average of multiple runs)
  local total_time=0
  local run_count=0

  for i in $(seq 1 "$RUNS"); do
    rm -f "$output"

    local start=$(date +%s%N 2>/dev/null || date +%s)

    if [[ "$VERBOSE" == "1" ]]; then
      "$ROOT/pdf-deflyt" -p "$preset" "$input" -o "$output" 2>&1
    else
      "$ROOT/pdf-deflyt" -p "$preset" "$input" -o "$output" >/dev/null 2>&1
    fi

    local end=$(date +%s%N 2>/dev/null || date +%s)

    # Calculate elapsed time in milliseconds
    if date +%s%N >/dev/null 2>&1; then
      # nanosecond precision available
      local elapsed=$(( (end - start) / 1000000 ))
    else
      # second precision only
      local elapsed=$(( (end - start) * 1000 ))
    fi

    total_time=$((total_time + elapsed))
    run_count=$((run_count + 1))
  done

  local avg_time=$((total_time / run_count))
  local output_size=$(size_of "$output")

  # Calculate compression ratio
  local ratio=0
  local savings=0
  if [[ $input_size -gt 0 ]]; then
    ratio=$(awk -v out="$output_size" -v in="$input_size" 'BEGIN{printf "%.2f", out/in}')
    savings=$(awk -v out="$output_size" -v in="$input_size" 'BEGIN{printf "%.1f", (1-out/in)*100}')
  fi

  # Output result in CSV format
  echo "$(basename "$input"),$preset,$input_size,$output_size,$ratio,$savings,$avg_time"
}

# Main benchmark suite
run_benchmarks() {
  log "Starting benchmark suite (${RUNS} runs per test)..."
  echo

  # CSV header
  echo "File,Preset,Input Size (bytes),Output Size (bytes),Ratio,Savings (%),Avg Time (ms)"

  # Test files (only if they exist)
  local -a test_files=()
  [[ -f "$ASSETS_DIR/mixed.pdf" ]] && test_files+=("$ASSETS_DIR/mixed.pdf")
  [[ -f "$ASSETS_DIR/rgb.pdf" ]] && test_files+=("$ASSETS_DIR/rgb.pdf")
  [[ -f "$ASSETS_DIR/gray.pdf" ]] && test_files+=("$ASSETS_DIR/gray.pdf")
  [[ -f "$ASSETS_DIR/mono.pdf" ]] && test_files+=("$ASSETS_DIR/mono.pdf")
  [[ -f "$ASSETS_DIR/structural.pdf" ]] && test_files+=("$ASSETS_DIR/structural.pdf")

  if [[ ${#test_files[@]} -eq 0 ]]; then
    echo "ERROR: No test files found in $ASSETS_DIR" >&2
    echo "Run 'make test' first to generate test fixtures" >&2
    exit 1
  fi

  # Presets to benchmark
  local -a presets=(light standard extreme lossless)

  # Run benchmarks
  for file in "${test_files[@]}"; do
    for preset in "${presets[@]}"; do
      info "Benchmarking: $(basename "$file") with preset=$preset"
      bench_one "$file" "$preset"
    done
  done

  echo
  success "Benchmark complete!"
}

# Summary report
generate_summary() {
  local csv="$BUILD_DIR/benchmark_results.csv"

  if [[ ! -f "$csv" ]]; then
    echo "No benchmark results found at $csv" >&2
    return 1
  fi

  echo
  log "Benchmark Summary"
  echo "==============================================================================="

  # Average compression ratio by preset
  echo
  echo "Average Compression Ratio by Preset:"
  awk -F, 'NR>1 {preset[$2]+=$5; count[$2]++}
           END {for (p in preset) printf "  %-12s  %.2f\n", p":", preset[p]/count[p]}' "$csv" | sort

  # Average savings by preset
  echo
  echo "Average Space Savings by Preset:"
  awk -F, 'NR>1 {savings[$2]+=$6; count[$2]++}
           END {for (p in savings) printf "  %-12s  %.1f%%\n", p":", savings[p]/count[p]}' "$csv" | sort

  # Average processing time by preset
  echo
  echo "Average Processing Time by Preset (ms):"
  awk -F, 'NR>1 {time[$2]+=$7; count[$2]++}
           END {for (p in time) printf "  %-12s  %d ms\n", p":", time[p]/count[p]}' "$csv" | sort

  echo
  echo "==============================================================================="
  echo
  info "Full results saved to: $csv"
}

# Main
main() {
  setup_bench

  local csv="$BUILD_DIR/benchmark_results.csv"
  run_benchmarks | tee "$csv"

  generate_summary

  # Cleanup intermediate files
  if [[ "$VERBOSE" != "1" ]]; then
    rm -f "$BUILD_DIR"/bench_*.pdf
  fi
}

# Help
usage() {
  cat <<EOF
Usage: $0 [OPTIONS]

Run performance benchmarks for pdf-deflyt

Options:
  -h, --help              Show this help message
  -v, --verbose           Show verbose output from pdf-deflyt
  -r, --runs N            Number of runs per test (default: 3)

Environment Variables:
  PDF_DEFLYT_BENCH_RUNS      Number of runs per test (default: 3)
  PDF_DEFLYT_BENCH_VERBOSE   Verbose mode: 0 or 1 (default: 0)

Examples:
  $0                      # Run with defaults
  $0 -v -r 5              # Verbose mode, 5 runs per test
  PDF_DEFLYT_BENCH_RUNS=10 $0  # 10 runs per test

EOF
  exit 0
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) usage ;;
    -v|--verbose) VERBOSE=1; shift ;;
    -r|--runs) RUNS="${2:-3}"; shift 2 ;;
    *) echo "Unknown option: $1" >&2; usage ;;
  esac
done

main
