#!/usr/bin/env bash
red() { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }

stat_size() {
  stat -f%z "$1" 2> /dev/null || stat -c%s "$1" 2> /dev/null || echo 0
}

stat_mtime() {
  stat -f%m "$1" 2> /dev/null || stat -c%Y "$1" 2> /dev/null || echo 0
}

# run_case <name> <cmd...>
run_case() {
  local name="$1"
  shift
  local log="$BUILD_DIR/logs/$name.log"
  mkdir -p "$(dirname "$log")"

  {
    echo "== $name =="
    printf 'argv:'
    for a in "$@"; do printf ' [%s]' "$a"; done
    printf '\n'
  } > "$log"

  local work_dir="${WORK_DIR:-$BUILD_DIR}"

  if (cd "$work_dir" && "$@") >> "$log" 2>&1; then
    green "Case OK: $name"
  else
    red "Case FAILED: $name"
    echo "Case FAILED: $name" >> "$log"
    mkdir -p "$BUILD_DIR"
    echo "$name" >> "$BUILD_DIR/failed"
    return 1
  fi
}
