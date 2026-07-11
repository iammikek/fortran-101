#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${BASE_URL:-http://127.0.0.1:8008}"

assert_json() {
  local path="$1"
  local expected="$2"
  local actual
  actual="$(curl -fsS "${BASE_URL}${path}")"
  if [[ "${actual}" != "${expected}" ]]; then
    echo "FAIL ${path}"
    echo " expected: ${expected}"
    echo " actual:   ${actual}"
    exit 1
  fi
  echo "OK ${path}"
}

assert_json "/" '{"message":"Hello from fortran-101"}'
assert_json "/health" '{"status":"ok"}'
assert_json "/categories" '{"items":[],"total":0,"skip":0,"limit":100}'
assert_json "/items" '{"items":[],"total":0,"skip":0,"limit":10}'
assert_json "/items/stats/summary" '{"total_items":0,"average_price":0.0,"min_price":null,"max_price":null,"uncategorized_count":0,"by_category":[]}'

echo "All fortran-101 API smoke tests passed."
