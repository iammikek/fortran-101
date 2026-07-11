#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

reset_db

assert_json GET /items/stats/summary 200 \
  '{"total_items":0,"average_price":0.0,"min_price":null,"max_price":null,"uncategorized_count":0,"by_category":[]}'

token="$(create_token)"
for pair in "A:10.0" "B:20.0" "C:30.0"; do
  name="${pair%%:*}"
  price="${pair##*:}"
  assert_status POST /items 201 "{\"name\":\"${name}\",\"price\":${price}}" 'application/json' "${token}"
done
assert_status GET /items/stats/summary 200
python3 - <<PY
import json
d = json.load(open("${BODY_FILE}"))
assert d['total_items'] == 3
assert d['average_price'] == 20.0
assert d['min_price'] == 10.0
assert d['max_price'] == 30.0
assert d['uncategorized_count'] == 3
assert d['by_category'] == []
PY
echo "OK GET /items/stats/summary returns item statistics"

reset_db
token="$(create_token)"
assert_status POST /categories 201 '{"name":"Tools"}' 'application/json' "${token}"
tools_id="$(python3 -c "import json; print(json.load(open('${BODY_FILE}'))['id'])")"
assert_status POST /categories 201 '{"name":"Books"}' 'application/json' "${token}"
books_id="$(python3 -c "import json; print(json.load(open('${BODY_FILE}'))['id'])")"
assert_status POST /items 201 "{\"name\":\"Hammer\",\"price\":10.0,\"category_id\":${tools_id}}" 'application/json' "${token}"
assert_status POST /items 201 "{\"name\":\"Drill\",\"price\":30.0,\"category_id\":${tools_id}}" 'application/json' "${token}"
assert_status POST /items 201 "{\"name\":\"Novel\",\"price\":15.0,\"category_id\":${books_id}}" 'application/json' "${token}"
assert_status POST /items 201 '{"name":"Loose","price":5.0}' 'application/json' "${token}"
assert_status GET /items/stats/summary 200
python3 - <<PY
import json
books_id = ${books_id}
tools_id = ${tools_id}
d = json.load(open("${BODY_FILE}"))
assert d['total_items'] == 4
assert d['uncategorized_count'] == 1
assert len(d['by_category']) == 2
assert d['by_category'][0] == {
    'category_id': books_id,
    'category_name': 'Books',
    'item_count': 1,
    'average_price': 15.0,
}
assert d['by_category'][1] == {
    'category_id': tools_id,
    'category_name': 'Tools',
    'item_count': 2,
    'average_price': 20.0,
}
PY
echo "OK GET /items/stats/summary includes per-category breakdown"
