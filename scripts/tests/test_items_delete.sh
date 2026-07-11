#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

reset_db

token="$(create_token)"
assert_status POST /items 201 '{"name":"To Delete","price":1.0}' 'application/json' "${token}"
item_id="$(python3 -c "import json; print(json.load(open('${BODY_FILE}'))['id'])")"
assert_status DELETE "/items/${item_id}" 204 '' '' "${token}"
assert_status GET "/items/${item_id}" 404
echo "OK DELETE /items/:id deletes item"

reset_db
token="$(create_token)"
assert_status POST /items 201 '{"name":"Widget","price":9.99}' 'application/json' "${token}"
item_id="$(python3 -c "import json; print(json.load(open('${BODY_FILE}'))['id'])")"
assert_status DELETE "/items/${item_id}" 401
assert_detail "Not authenticated"
echo "OK DELETE /items/:id without auth is unauthorized"

reset_db
token="$(create_token)"
assert_status POST /items 201 '{"name":"Widget","price":9.99}' 'application/json' "${token}"
item_id="$(python3 -c "import json; print(json.load(open('${BODY_FILE}'))['id'])")"
assert_status DELETE "/items/${item_id}" 401 '' '' 'invalid-token'
assert_detail "Could not validate credentials"
echo "OK DELETE /items/:id rejects invalid JWT"

reset_db
token="$(create_token)"
assert_status DELETE /items/99 404 '' '' "${token}"
assert_detail "Item not found"
echo "OK DELETE /items/:id returns 404 when not found"
