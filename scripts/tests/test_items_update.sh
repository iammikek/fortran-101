#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

wait_for_health
reset_db

token="$(create_token)"
assert_status POST /items 201 '{"name":"Widget","description":"Original","price":10.0}' 'application/json' "${token}"
item_id="$(python3 -c "import json; print(json.load(open('${BODY_FILE}'))['id'])")"
assert_status PATCH "/items/${item_id}" 200 '{"price":5.99}' 'application/json' "${token}"
name="$(python3 -c "import json; print(json.load(open('${BODY_FILE}'))['name'])")"
desc="$(python3 -c "import json; print(json.load(open('${BODY_FILE}'))['description'])")"
price="$(python3 -c "import json; print(json.load(open('${BODY_FILE}'))['price'])")"
[[ "${name}" == "Widget" && "${desc}" == "Original" && "${price}" == "5.99" ]] || { echo "FAIL partial item update"; exit 1; }
echo "OK PATCH /items/:id partial update"

reset_db
token="$(create_token)"
assert_status POST /items 201 '{"name":"Old","price":1.0}' 'application/json' "${token}"
item_id="$(python3 -c "import json; print(json.load(open('${BODY_FILE}'))['id'])")"
assert_status PATCH "/items/${item_id}" 200 '{"name":"New","description":"Updated","price":2.5}' 'application/json' "${token}"
name="$(python3 -c "import json; print(json.load(open('${BODY_FILE}'))['name'])")"
desc="$(python3 -c "import json; print(json.load(open('${BODY_FILE}'))['description'])")"
price="$(python3 -c "import json; print(json.load(open('${BODY_FILE}'))['price'])")"
has_cat="$(python3 -c "import json; print('category_id' in json.load(open('${BODY_FILE}')))")"
[[ "${name}" == "New" && "${desc}" == "Updated" && "${price}" == "2.5" && "${has_cat}" == "True" ]] \
  || { echo "FAIL full item update"; exit 1; }
echo "OK PATCH /items/:id full update"

reset_db
token="$(create_token)"
assert_status POST /items 201 '{"name":"Widget","price":9.99}' 'application/json' "${token}"
item_id="$(python3 -c "import json; print(json.load(open('${BODY_FILE}'))['id'])")"
assert_status POST /categories 201 '{"name":"Tools"}' 'application/json' "${token}"
cat_id="$(python3 -c "import json; print(json.load(open('${BODY_FILE}'))['id'])")"
assert_status PATCH "/items/${item_id}" 200 "{\"category_id\":${cat_id}}" 'application/json' "${token}"
cat_name="$(python3 -c "import json; print(json.load(open('${BODY_FILE}'))['category']['name'])")"
[[ "${cat_name}" == "Tools" ]] || { echo "FAIL item category update"; exit 1; }
echo "OK PATCH /items/:id updates category_id"

reset_db
token="$(create_token)"
assert_status PATCH /items/99 404 '{"name":"Nope"}' 'application/json' "${token}"
assert_detail "Item not found"
echo "OK PATCH /items/:id returns 404 when not found"

reset_db
token="$(create_token)"
assert_status POST /items 201 '{"name":"Widget","price":9.99}' 'application/json' "${token}"
item_id="$(python3 -c "import json; print(json.load(open('${BODY_FILE}'))['id'])")"
assert_status PATCH "/items/${item_id}" 401 '{"name":"Nope"}' 'application/json'
assert_detail "Not authenticated"
echo "OK PATCH /items/:id without auth is unauthorized"
