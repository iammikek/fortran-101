#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

wait_for_health
reset_db

token="$(create_token)"
assert_status POST /items 201 '{"name":"Widget","price":9.99}' 'application/json' "${token}"
item_id="$(python3 -c "import json; print(json.load(open('${BODY_FILE}'))['id'])")"
assert_status GET "/items/${item_id}" 200
name="$(python3 -c "import json; print(json.load(open('${BODY_FILE}'))['name'])")"
[[ "${name}" == "Widget" ]] || { echo "FAIL get item"; exit 1; }
echo "OK GET /items/:id returns item"

reset_db
assert_status GET /items/99 404
assert_detail "Item not found"
code="$(python3 -c "import json; print(json.load(open('${BODY_FILE}'))['code'])")"
[[ "${code}" == "ITEM_NOT_FOUND" ]] || { echo "FAIL item 404 code"; exit 1; }
echo "OK GET /items/:id returns 404 when not found"
