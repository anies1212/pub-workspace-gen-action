#!/usr/bin/env bash
#
# Unit tests for scripts/run.sh
#
# Usage: bash tests/test_run.sh
#
set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
FIXTURE_DIR="$SCRIPT_DIR/fixtures/workspace"

# ---------------------------------------------------------------------------
# Test framework
# ---------------------------------------------------------------------------
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

pass() {
  ((TESTS_PASSED++))
  echo "  PASS: $1"
}

fail() {
  ((TESTS_FAILED++))
  echo "  FAIL: $1"
  echo "        Expected: $2"
  echo "        Actual:   $3"
}

assert_eq() {
  local label="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    pass "$label"
  else
    fail "$label" "$expected" "$actual"
  fi
}

assert_contains() {
  local label="$1" expected="$2" actual="$3"
  if echo "$actual" | grep -q "$expected"; then
    pass "$label"
  else
    fail "$label" "contains '$expected'" "$actual"
  fi
}

assert_not_contains() {
  local label="$1" unexpected="$2" actual="$3"
  if ! echo "$actual" | grep -q "$unexpected"; then
    pass "$label"
  else
    fail "$label" "does not contain '$unexpected'" "$actual"
  fi
}

# ---------------------------------------------------------------------------
# Source the script functions (override main to prevent execution)
# ---------------------------------------------------------------------------
source_run_sh() {
  # Source only the function definitions from run.sh (skip set -euo, config, and main call)
  eval "$(sed -n '/^# Helpers/,/^main()/{ /^main()/d; p; }' "$PROJECT_DIR/scripts/run.sh" | sed '/^set -/d')"
}

# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------
test_discover_packages() {
  echo "test_discover_packages"
  ((TESTS_RUN++))

  source_run_sh

  local result
  result="$(discover_packages "$FIXTURE_DIR")"

  assert_contains "finds pkg_a (has build_runner)" "pkg_a" "$result"
  assert_contains "finds pkg_b (has build_runner)" "pkg_b" "$result"
  assert_not_contains "skips pkg_no_gen (no build_runner)" "pkg_no_gen" "$result"
}

test_discover_packages_empty() {
  echo "test_discover_packages_empty"
  ((TESTS_RUN++))

  source_run_sh

  local empty_dir
  empty_dir="$(mktemp -d)"
  mkdir -p "$empty_dir/packages"

  local result
  result="$(discover_packages "$empty_dir")"

  assert_eq "empty workspace returns empty" "" "$result"

  rm -rf "$empty_dir"
}

test_has_build_runner_true() {
  echo "test_has_build_runner_true"
  ((TESTS_RUN++))

  source_run_sh

  if has_build_runner "$FIXTURE_DIR"; then
    pass "root has build_runner"
  else
    fail "root has build_runner" "true" "false"
  fi
}

test_has_build_runner_false() {
  echo "test_has_build_runner_false"
  ((TESTS_RUN++))

  source_run_sh

  if has_build_runner "$FIXTURE_DIR/packages/pkg_no_gen"; then
    fail "pkg_no_gen should not have build_runner" "false" "true"
  else
    pass "pkg_no_gen does not have build_runner"
  fi
}

test_set_output() {
  echo "test_set_output"
  ((TESTS_RUN++))

  source_run_sh

  local tmp_output
  tmp_output="$(mktemp)"
  GITHUB_OUTPUT="$tmp_output"

  set_output "packages" "pkg_a,pkg_b"

  local content
  content="$(cat "$tmp_output")"
  assert_eq "output is written" "packages=pkg_a,pkg_b" "$content"

  rm -f "$tmp_output"
}

test_set_output_no_github() {
  echo "test_set_output_no_github"
  ((TESTS_RUN++))

  source_run_sh

  unset GITHUB_OUTPUT 2>/dev/null || true

  # Should not error when GITHUB_OUTPUT is not set
  set_output "key" "value"
  pass "no error without GITHUB_OUTPUT"
}

# ---------------------------------------------------------------------------
# Run all tests
# ---------------------------------------------------------------------------
echo "Running tests..."
echo ""

test_discover_packages
test_discover_packages_empty
test_has_build_runner_true
test_has_build_runner_false
test_set_output
test_set_output_no_github

echo ""
echo "Results: $TESTS_PASSED passed, $TESTS_FAILED failed (out of $TESTS_RUN test groups)"

if [ "$TESTS_FAILED" -gt 0 ]; then
  exit 1
fi
