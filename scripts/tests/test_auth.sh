#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

wait_for_health
reset_db

assert_status POST /auth/register 201 '{"email":"alice@example.com","password":"password123"}' 'application/json'
body="$(cat "${BODY_FILE}")"
assert_json_path "${body}" email alice@example.com
if echo "${body}" | python3 -c "import json,sys; d=json.load(sys.stdin); sys.exit(0 if 'password' not in d and 'hashed_password' not in d else 1)"; then
  echo "OK POST /auth/register creates user"
else
  echo "FAIL register should not return password"
  exit 1
fi

reset_db
assert_status POST /auth/register 201 '{"email":"test@example.com","password":"secret123"}' 'application/json'
assert_status POST /auth/register 409 '{"email":"test@example.com","password":"secret123"}' 'application/json'
code="$(python3 -c "import json; print(json.load(open('${BODY_FILE}'))['code'])")"
[[ "${code}" == "USER_EMAIL_EXISTS" ]] || { echo "FAIL duplicate register code"; exit 1; }
echo "OK POST /auth/register rejects duplicate email"

reset_db
assert_status POST /auth/register 201 '{"email":"test@example.com","password":"secret123"}' 'application/json'
assert_status POST /auth/login 200 'username=test@example.com&password=secret123' 'application/x-www-form-urlencoded'
token_type="$(python3 -c "import json; print(json.load(open('${BODY_FILE}'))['token_type'])")"
access_token="$(python3 -c "import json; print(json.load(open('${BODY_FILE}'))['access_token'])")"
[[ "${token_type}" == "bearer" && -n "${access_token}" ]] || { echo "FAIL login token"; exit 1; }
echo "OK POST /auth/login returns bearer token"

reset_db
assert_status POST /auth/register 201 '{"email":"test@example.com","password":"secret123"}' 'application/json'
assert_status POST /auth/login 401 'username=test@example.com&password=wrong-password' 'application/x-www-form-urlencoded'
assert_detail "Incorrect email or password"
echo "OK POST /auth/login rejects invalid password"

reset_db
token="$(create_token)"
assert_status GET /auth/me 200 '' '' "${token}"
email="$(python3 -c "import json; print(json.load(open('${BODY_FILE}'))['email'])")"
[[ "${email}" == "test@example.com" ]] || { echo "FAIL auth/me email"; exit 1; }
echo "OK GET /auth/me returns current user"

reset_db
assert_status GET /auth/me 401
assert_detail "Not authenticated"
echo "OK GET /auth/me without token is unauthorized"
