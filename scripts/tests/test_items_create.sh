#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

reset_db

token="$(create_token)"
assert_status POST /items 201 '{"name":"Widget","description":"A nice widget","price":9.99}' 'application/json' "${token}"
body="$(cat "${BODY_FILE}")"
assert_json_path "${body}" name Widget
assert_json_path "${body}" description "A nice widget"
assert_json_path "${body}" price 9.99
id="$(python3 -c "import json; print(json.load(open('${BODY_FILE}'))['id'])")"
[[ "${id}" -ge 1 ]] || { echo "FAIL item id"; exit 1; }
echo "OK POST /items creates item"

reset_db
token="$(create_token)"
assert_status POST /items 201 '{"name":"Thing","price":5.0}' 'application/json' "${token}"
desc="$(python3 -c "import json; d=json.load(open('${BODY_FILE}')); print('null' if d['description'] is None else d['description'])")"
[[ "${desc}" == "null" ]] || { echo "FAIL optional description"; exit 1; }
echo "OK POST /items accepts missing description"

reset_db
token="$(create_token)"
assert_status POST /categories 201 '{"name":"Electronics"}' 'application/json' "${token}"
cat_id="$(python3 -c "import json; print(json.load(open('${BODY_FILE}'))['id'])")"
assert_status POST /items 201 "{\"name\":\"Gadget\",\"price\":15.0,\"category_id\":${cat_id}}" 'application/json' "${token}"
cat_name="$(python3 -c "import json; print(json.load(open('${BODY_FILE}'))['category']['name'])")"
[[ "${cat_name}" == "Electronics" ]] || { echo "FAIL nested category on create"; exit 1; }
echo "OK POST /items with category returns nested category"

reset_db
token="$(create_token)"
assert_status POST /items 404 '{"name":"Gadget","price":15.0,"category_id":999}' 'application/json' "${token}"
code="$(python3 -c "import json; print(json.load(open('${BODY_FILE}'))['code'])")"
[[ "${code}" == "CATEGORY_NOT_FOUND" ]] || { echo "FAIL invalid category on create"; exit 1; }
echo "OK POST /items rejects invalid category_id"

reset_db
assert_status POST /items 401 '{"name":"Thing","price":5.0}' 'application/json'
assert_detail "Not authenticated"
echo "OK POST /items without auth is unauthorized"
