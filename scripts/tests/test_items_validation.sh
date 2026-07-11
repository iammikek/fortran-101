#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

reset_db

token="$(create_token)"
for payload in '{"name":"No price"}' '{"name":"Bad","price":-1.0}' '{"name":"","price":1.0}'; do
  assert_status POST /items 422 "${payload}" 'application/json' "${token}"
done
echo "OK POST /items returns 422 for invalid payloads"
