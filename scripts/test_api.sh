#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="${SCRIPT_DIR}/tests"

# shellcheck source=tests/common.sh
source "${TESTS_DIR}/common.sh"

export BASE_URL CONTAINER_NAME

TEST_SCRIPTS=(
  test_app.sh
  test_auth.sh
  test_categories.sh
  test_items_create.sh
  test_items_read.sh
  test_items_delete.sh
  test_items_list.sh
  test_items_validation.sh
  test_items_update.sh
  test_items_stats.sh
)

echo "Running 47 fortran-101 feature tests (fastAPI-101 parity)..."

wait_for_health

for script in "${TEST_SCRIPTS[@]}"; do
  echo "==> ${script}"
  bash "${TESTS_DIR}/${script}"
done

echo "All 47 fortran-101 fastAPI-101 parity tests passed."
