#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

wait_for_health
reset_db

# Create (3)
token="$(create_token)"
assert_status POST /categories 201 '{"name":"Tools","description":"Hand tools"}' 'application/json' "${token}"
body="$(cat "${BODY_FILE}")"
assert_json_path "${body}" name Tools
assert_json_path "${body}" description "Hand tools"
id="$(python3 -c "import json; print(json.load(open('${BODY_FILE}'))['id'])")"
[[ "${id}" -ge 1 ]] || { echo "FAIL category id"; exit 1; }
echo "OK POST /categories creates category"

reset_db
assert_status POST /categories 401 '{"name":"Tools"}' 'application/json'
echo "OK POST /categories without auth is unauthorized"

reset_db
token="$(create_token)"
assert_status POST /categories 201 '{"name":"foo"}' 'application/json' "${token}"
assert_status POST /categories 409 '{"name":"foo","description":"duplicate"}' 'application/json' "${token}"
code="$(python3 -c "import json; print(json.load(open('${BODY_FILE}'))['code'])")"
[[ "${code}" == "CATEGORY_NAME_EXISTS" ]] || { echo "FAIL duplicate category code"; exit 1; }
echo "OK POST /categories rejects duplicate name"

reset_db

# List (4)
assert_json GET /categories 200 '{"items":[],"total":0,"skip":0,"limit":10}'

token="$(create_token)"
for name in A B C; do
  assert_status POST /categories 201 "{\"name\":\"${name}\"}" 'application/json' "${token}"
done
assert_status GET '/categories?skip=1&limit=2' 200
total="$(python3 -c "import json; print(json.load(open('${BODY_FILE}'))['total'])")"
skip="$(python3 -c "import json; print(json.load(open('${BODY_FILE}'))['skip'])")"
limit="$(python3 -c "import json; print(json.load(open('${BODY_FILE}'))['limit'])")"
count="$(python3 -c "import json; print(len(json.load(open('${BODY_FILE}'))['items']))")"
name0="$(python3 -c "import json; print(json.load(open('${BODY_FILE}'))['items'][0]['name'])")"
name1="$(python3 -c "import json; print(json.load(open('${BODY_FILE}'))['items'][1]['name'])")"
[[ "${total}" == "3" && "${skip}" == "1" && "${limit}" == "2" && "${count}" == "2" && "${name0}" == "B" && "${name1}" == "C" ]] \
  || { echo "FAIL categories pagination"; exit 1; }
echo "OK GET /categories supports pagination"

reset_db
token="$(create_token)"
assert_status POST /categories 201 '{"name":"Books"}' 'application/json' "${token}"
cat_id="$(python3 -c "import json; print(json.load(open('${BODY_FILE}'))['id'])")"
assert_status GET "/categories/${cat_id}" 200
name="$(python3 -c "import json; print(json.load(open('${BODY_FILE}'))['name'])")"
[[ "${name}" == "Books" ]] || { echo "FAIL get category"; exit 1; }
echo "OK GET /categories/:id returns category"

reset_db
assert_status GET /categories/999 404
code="$(python3 -c "import json; print(json.load(open('${BODY_FILE}'))['code'])")"
[[ "${code}" == "CATEGORY_NOT_FOUND" ]] || { echo "FAIL category 404 code"; exit 1; }
echo "OK GET /categories/:id returns 404 when not found"

reset_db

# Update/delete (3)
token="$(create_token)"
assert_status POST /categories 201 '{"name":"Old Name"}' 'application/json' "${token}"
cat_id="$(python3 -c "import json; print(json.load(open('${BODY_FILE}'))['id'])")"
assert_status PATCH "/categories/${cat_id}" 200 '{"name":"New Name","description":"Updated"}' 'application/json' "${token}"
name="$(python3 -c "import json; print(json.load(open('${BODY_FILE}'))['name'])")"
desc="$(python3 -c "import json; print(json.load(open('${BODY_FILE}'))['description'])")"
[[ "${name}" == "New Name" && "${desc}" == "Updated" ]] || { echo "FAIL category update"; exit 1; }
echo "OK PATCH /categories/:id updates category"

reset_db
token="$(create_token)"
assert_status POST /categories 201 '{"name":"Temporary"}' 'application/json' "${token}"
cat_id="$(python3 -c "import json; print(json.load(open('${BODY_FILE}'))['id'])")"
assert_status DELETE "/categories/${cat_id}" 204 '' '' "${token}"
assert_status GET "/categories/${cat_id}" 404
echo "OK DELETE /categories/:id deletes unused category"

reset_db
token="$(create_token)"
assert_status POST /categories 201 '{"name":"Tools"}' 'application/json' "${token}"
cat_id="$(python3 -c "import json; print(json.load(open('${BODY_FILE}'))['id'])")"
assert_status POST /items 201 "{\"name\":\"Hammer\",\"price\":10.0,\"category_id\":${cat_id}}" 'application/json' "${token}"
assert_status DELETE "/categories/${cat_id}" 409 '' '' "${token}"
code="$(python3 -c "import json; print(json.load(open('${BODY_FILE}'))['code'])")"
[[ "${code}" == "CATEGORY_IN_USE" ]] || { echo "FAIL category in use code"; exit 1; }
echo "OK DELETE /categories/:id rejects category in use"
