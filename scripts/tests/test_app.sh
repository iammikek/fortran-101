#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

reset_db

assert_json GET / 200 '{"message":"Hello from fortran-101"}'
assert_json GET /health 200 '{"status":"ok","database":"connected"}'
