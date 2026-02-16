#!/usr/bin/env bash
#
# Run build_runner across Dart/Flutter pub workspace packages in parallel.
#
# Environment variables (set by action.yml):
#   INPUT_WORKING_DIRECTORY  - Workspace root directory (default: .)
#   INPUT_CONCURRENCY        - Max parallel jobs, 0 = unlimited (default: 0)
#   INPUT_INCLUDE_ROOT       - Run build_runner in root package (default: true)
#   INPUT_BUILD_RUNNER_ARGS  - Extra build_runner arguments
#
set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
WORKING_DIR="${INPUT_WORKING_DIRECTORY:-.}"
CONCURRENCY="${INPUT_CONCURRENCY:-0}"
INCLUDE_ROOT="${INPUT_INCLUDE_ROOT:-true}"
# shellcheck disable=SC2206
BUILD_RUNNER_ARGS=(${INPUT_BUILD_RUNNER_ARGS:---delete-conflicting-outputs})

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
log_info()  { echo "::notice::$*"; }
log_error() { echo "::error::$*"; }
log_group() { echo "::group::$1"; }
log_endgroup() { echo "::endgroup::"; }

set_output() {
  if [ -n "${GITHUB_OUTPUT:-}" ]; then
    echo "$1=$2" >> "$GITHUB_OUTPUT"
  fi
}

# ---------------------------------------------------------------------------
# Package discovery
# ---------------------------------------------------------------------------
discover_packages() {
  local dir="$1"
  local packages=()

  for pkg in "$dir"/packages/*/; do
    [ -d "$pkg" ] || continue
    if [ -f "$pkg/pubspec.yaml" ] && grep -q 'build_runner' "$pkg/pubspec.yaml" 2>/dev/null; then
      packages+=("$pkg")
    fi
  done

  echo "${packages[@]}"
}

has_build_runner() {
  local dir="$1"
  [ -f "$dir/pubspec.yaml" ] && grep -q 'build_runner' "$dir/pubspec.yaml" 2>/dev/null
}

# ---------------------------------------------------------------------------
# Build runner execution
# ---------------------------------------------------------------------------
run_single() {
  local pkg="$1"
  local name
  name="$(basename "$pkg")"
  local log_file="$LOG_DIR/$name.log"

  if (cd "$pkg" && dart run build_runner build "${BUILD_RUNNER_ARGS[@]}") > "$log_file" 2>&1; then
    return 0
  else
    return 1
  fi
}

print_logs() {
  for log_file in "$LOG_DIR"/*.log; do
    [ -f "$log_file" ] || continue
    local name
    name="$(basename "$log_file" .log)"
    log_group "$name"
    cat "$log_file"
    log_endgroup
  done
}

# Run a batch of packages in parallel and wait for all to complete.
# Compatible with bash 3.2+ (macOS default).
run_batch() {
  local batch_pids=()
  local batch_names=()
  local batch_failed=0

  for pkg in "$@"; do
    run_single "$pkg" &
    batch_pids+=($!)
    batch_names+=("$(basename "$pkg")")
  done

  for i in "${!batch_pids[@]}"; do
    if ! wait "${batch_pids[$i]}"; then
      log_error "build_runner failed in ${batch_names[$i]}"
      batch_failed=1
    fi
  done

  return $batch_failed
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
  cd "$WORKING_DIR"

  LOG_DIR="$(mktemp -d)"
  trap 'print_logs; rm -rf "$LOG_DIR"' EXIT

  # Discover packages
  local discovered
  discovered="$(discover_packages ".")"
  local packages=()
  if [ -n "$discovered" ]; then
    read -ra packages <<< "$discovered"
  fi

  if [ ${#packages[@]} -eq 0 ] && [ "$INCLUDE_ROOT" != "true" ]; then
    log_info "No packages with build_runner found"
    set_output "packages" ""
    return 0
  fi

  local total=${#packages[@]}
  [ "$INCLUDE_ROOT" = "true" ] && has_build_runner "." && total=$((total + 1))
  echo "Found $total target(s) with build_runner"

  # Step 1: Run root package first (sequential)
  if [ "$INCLUDE_ROOT" = "true" ] && has_build_runner "."; then
    echo "Running build_runner in root..."
    local root_log="$LOG_DIR/root.log"
    if ! (dart run build_runner build "${BUILD_RUNNER_ARGS[@]}") > "$root_log" 2>&1; then
      log_error "build_runner failed in root"
      exit 1
    fi
  fi

  # Step 2: Run workspace packages in parallel
  if [ ${#packages[@]} -eq 0 ]; then
    set_output "packages" ""
    return 0
  fi

  local max_jobs=$CONCURRENCY
  if [ "$max_jobs" -eq 0 ]; then
    max_jobs=${#packages[@]}
  fi

  echo "Running build_runner in ${#packages[@]} package(s) (concurrency: $max_jobs)..."

  local failed=0
  local batch=()

  for pkg in "${packages[@]}"; do
    batch+=("$pkg")
    if [ ${#batch[@]} -ge "$max_jobs" ]; then
      run_batch "${batch[@]}" || failed=1
      batch=()
    fi
  done

  if [ ${#batch[@]} -gt 0 ]; then
    run_batch "${batch[@]}" || failed=1
  fi

  # Set output
  local pkg_names=()
  for pkg in "${packages[@]}"; do
    pkg_names+=("$(basename "$pkg")")
  done
  local joined
  joined="$(IFS=,; echo "${pkg_names[*]}")"
  set_output "packages" "$joined"

  if [ "$failed" -ne 0 ]; then
    log_error "One or more packages failed"
    exit 1
  fi

  echo "All packages generated successfully"
}

main "$@"
