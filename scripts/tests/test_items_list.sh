#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

reset_db

assert_json GET /items 200 '{"items":[],"total":0,"skip":0,"limit":10}'

token="$(create_token)"
for pair in "A:1.0" "B:2.0" "C:3.0"; do
  name="${pair%%:*}"
  price="${pair##*:}"
  assert_status POST /items 201 "{\"name\":\"${name}\",\"price\":${price}}" 'application/json' "${token}"
done
assert_status GET '/items?skip=1&limit=2' 200
total="$(python3 -c "import json; print(json.load(open('${BODY_FILE}'))['total'])")"
skip="$(python3 -c "import json; print(json.load(open('${BODY_FILE}'))['skip'])")"
limit="$(python3 -c "import json; print(json.load(open('${BODY_FILE}'))['limit'])")"
count="$(python3 -c "import json; print(len(json.load(open('${BODY_FILE}'))['items']))")"
name0="$(python3 -c "import json; print(json.load(open('${BODY_FILE}'))['items'][0]['name'])")"
name1="$(python3 -c "import json; print(json.load(open('${BODY_FILE}'))['items'][1]['name'])")"
[[ "${total}" == "3" && "${skip}" == "1" && "${limit}" == "2" && "${count}" == "2" && "${name0}" == "B" && "${name1}" == "C" ]] \
  || { echo "FAIL pagination"; exit 1; }
echo "OK GET /items supports pagination"

reset_db
token="$(create_token)"
for pair in "Cheap:5.0" "Mid:10.0" "Premium:25.0"; do
  name="${pair%%:*}"
  price="${pair##*:}"
  assert_status POST /items 201 "{\"name\":\"${name}\",\"price\":${price}}" 'application/json' "${token}"
done
assert_status GET '/items?min_price=10' 200
total="$(python3 -c "import json; print(json.load(open('${BODY_FILE}'))['total'])")"
names="$(python3 -c "import json; print(','.join(sorted(i['name'] for i in json.load(open('${BODY_FILE}'))['items'])))")"
[[ "${total}" == "2" && "${names}" == "Mid,Premium" ]] || { echo "FAIL min_price filter"; exit 1; }
echo "OK GET /items filters by min_price"

reset_db
token="$(create_token)"
for pair in "Cheap:5.0" "Mid:10.0" "Premium:25.0"; do
  name="${pair%%:*}"
  price="${pair##*:}"
  assert_status POST /items 201 "{\"name\":\"${name}\",\"price\":${price}}" 'application/json' "${token}"
done
assert_status GET '/items?max_price=10' 200
total="$(python3 -c "import json; print(json.load(open('${BODY_FILE}'))['total'])")"
names="$(python3 -c "import json; print(','.join(sorted(i['name'] for i in json.load(open('${BODY_FILE}'))['items'])))")"
[[ "${total}" == "2" && "${names}" == "Cheap,Mid" ]] || { echo "FAIL max_price filter"; exit 1; }
echo "OK GET /items filters by max_price"

reset_db
token="$(create_token)"
assert_status POST /categories 201 '{"name":"Tools"}' 'application/json' "${token}"
tools_id="$(python3 -c "import json; print(json.load(open('${BODY_FILE}'))['id'])")"
assert_status POST /categories 201 '{"name":"Books"}' 'application/json' "${token}"
books_id="$(python3 -c "import json; print(json.load(open('${BODY_FILE}'))['id'])")"
assert_status POST /items 201 "{\"name\":\"Hammer\",\"price\":10.0,\"category_id\":${tools_id}}" 'application/json' "${token}"
assert_status POST /items 201 "{\"name\":\"Novel\",\"price\":12.0,\"category_id\":${books_id}}" 'application/json' "${token}"
assert_status POST /items 201 "{\"name\":\"Wrench\",\"price\":15.0,\"category_id\":${tools_id}}" 'application/json' "${token}"
assert_status GET "/items?category_id=${tools_id}" 200
total="$(python3 -c "import json; print(json.load(open('${BODY_FILE}'))['total'])")"
names="$(python3 -c "import json; print(','.join(sorted(i['name'] for i in json.load(open('${BODY_FILE}'))['items'])))")"
[[ "${total}" == "2" && "${names}" == "Hammer,Wrench" ]] || { echo "FAIL category filter"; exit 1; }
echo "OK GET /items filters by category_id"

reset_db
token="$(create_token)"
for pair in "Blue Widget:10.0" "Red Gadget:12.0" "green widget:15.0"; do
  name="${pair%%:*}"
  price="${pair##*:}"
  assert_status POST /items 201 "{\"name\":\"${name}\",\"price\":${price}}" 'application/json' "${token}"
done
assert_status GET '/items?name_contains=widget' 200
total="$(python3 -c "import json; print(json.load(open('${BODY_FILE}'))['total'])")"
names="$(python3 -c "import json; print(','.join(sorted(i['name'] for i in json.load(open('${BODY_FILE}'))['items'])))")"
[[ "${total}" == "2" && "${names}" == "Blue Widget,green widget" ]] || { echo "FAIL name_contains filter"; exit 1; }
echo "OK GET /items filters by name_contains"

reset_db
token="$(create_token)"
assert_status POST /categories 201 '{"name":"Tools"}' 'application/json' "${token}"
tools_id="$(python3 -c "import json; print(json.load(open('${BODY_FILE}'))['id'])")"
assert_status POST /categories 201 '{"name":"Books"}' 'application/json' "${token}"
books_id="$(python3 -c "import json; print(json.load(open('${BODY_FILE}'))['id'])")"
assert_status POST /items 201 "{\"name\":\"Budget Tool\",\"price\":8.0,\"category_id\":${tools_id}}" 'application/json' "${token}"
assert_status POST /items 201 "{\"name\":\"Pro Tool\",\"price\":20.0,\"category_id\":${tools_id}}" 'application/json' "${token}"
assert_status POST /items 201 "{\"name\":\"Budget Book\",\"price\":8.0,\"category_id\":${books_id}}" 'application/json' "${token}"
assert_status GET "/items?category_id=${tools_id}&min_price=10&max_price=25" 200
total="$(python3 -c "import json; print(json.load(open('${BODY_FILE}'))['total'])")"
name="$(python3 -c "import json; print(json.load(open('${BODY_FILE}'))['items'][0]['name'])")"
[[ "${total}" == "1" && "${name}" == "Pro Tool" ]] || { echo "FAIL combined filters"; exit 1; }
echo "OK GET /items supports combined filters"

for query in limit=101 skip=-1 min_price=-1; do
  reset_db
  assert_status GET "/items?${query}" 422
  echo "OK GET /items returns 422 for ${query}"
done
