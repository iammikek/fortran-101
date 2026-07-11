#!/usr/bin/env bash
# Shared helpers for fortran-101 feature tests (fastAPI-101 parity).

BASE_URL="${BASE_URL:-http://127.0.0.1:8008}"
CONTAINER_NAME="${CONTAINER_NAME:-}"
BODY_FILE="$(mktemp)"
trap 'rm -f "${BODY_FILE}"' EXIT

# Bound all HTTP calls so a stuck single-threaded server cannot hang the suite.
CURL_OPTS=(-sS --connect-timeout 2 --max-time 10)

wait_for_health() {
  local attempt ready=0
  for attempt in $(seq 1 50); do
    if curl "${CURL_OPTS[@]}" -f "${BASE_URL}/health" >/dev/null 2>&1 \
      && curl "${CURL_OPTS[@]}" -f "${BASE_URL}/" >/dev/null 2>&1; then
      ready=$((ready + 1))
      if [[ "${ready}" -ge 3 ]]; then
        return 0
      fi
    else
      ready=0
    fi
    sleep 0.2
  done
  echo "FAIL server not healthy at ${BASE_URL}/health after 10s"
  exit 1
}

reset_db() {
  if [[ -n "${CONTAINER_NAME}" ]]; then
    local attempt users
    for attempt in $(seq 1 20); do
      if docker exec "${CONTAINER_NAME}" sqlite3 /app/database/database.sqlite \
        "DELETE FROM items; DELETE FROM categories; DELETE FROM users; DELETE FROM sqlite_sequence WHERE name IN ('items','categories','users');" \
        >/dev/null 2>&1; then
        users="$(docker exec "${CONTAINER_NAME}" sqlite3 /app/database/database.sqlite \
          "SELECT COUNT(*) FROM users;" 2>/dev/null || echo err)"
        if [[ "${users}" == "0" ]]; then
          sleep 0.2
          return 0
        fi
      fi
      sleep 0.2
    done
    echo "FAIL could not reset database after 20 attempts (database locked?)"
    exit 1
  fi
}

assert_status() {
  local method="$1"
  local path="$2"
  local expected="$3"
  local body="${4:-}"
  local content_type="${5:-}"
  local auth="${6:-}"
  local actual
  local args=("${CURL_OPTS[@]}" -o "${BODY_FILE}" -w "%{http_code}" -X "${method}")

  if [[ -n "${content_type}" ]]; then
    args+=(-H "Content-Type: ${content_type}")
  fi
  if [[ -n "${auth}" ]]; then
    args+=(-H "Authorization: Bearer ${auth}")
  fi
  if [[ -n "${body}" ]]; then
    args+=(-d "${body}")
  fi

  actual="$(curl "${args[@]}" "${BASE_URL}${path}" || true)"
  if [[ -z "${actual}" ]]; then
    actual="000"
  fi
  if [[ "${actual}" != "${expected}" ]]; then
    echo "FAIL ${method} ${path} expected status ${expected}, got ${actual}"
    cat "${BODY_FILE}" || true
    exit 1
  fi
}

assert_json() {
  local method="$1"
  local path="$2"
  local expected_status="$3"
  local expected_body="$4"
  local body="${5:-}"
  local content_type="${6:-}"
  local auth="${7:-}"

  assert_status "${method}" "${path}" "${expected_status}" "${body}" "${content_type}" "${auth}"
  actual="$(cat "${BODY_FILE}")"
  if [[ "${actual}" != "${expected_body}" ]]; then
    echo "FAIL ${method} ${path}"
    echo " expected: ${expected_body}"
    echo " actual:   ${actual}"
    exit 1
  fi
  echo "OK ${method} ${path}"
}

assert_json_path() {
  local json="$1"
  local path="$2"
  local expected="$3"
  local actual
  actual="$(PYTHON_JSON="${json}" PYTHON_PATH="${path}" python3 - <<'PY'
import json, os
d = json.loads(os.environ["PYTHON_JSON"])
for k in os.environ["PYTHON_PATH"].split("."):
    d = d[int(k)] if isinstance(d, list) and k.isdigit() else d[k]
print(d)
PY
)"
  if [[ "${actual}" != "${expected}" ]]; then
    echo "FAIL json path ${path}: expected ${expected}, got ${actual}"
    exit 1
  fi
}

assert_detail() {
  local expected="$1"
  local actual
  actual="$(python3 -c "import json; print(json.load(open('${BODY_FILE}'))['detail'])")"
  if [[ "${actual}" != "${expected}" ]]; then
    echo "FAIL detail: expected ${expected}, got ${actual}"
    cat "${BODY_FILE}" || true
    exit 1
  fi
}

create_token() {
  local attempt token
  for attempt in $(seq 1 8); do
    curl "${CURL_OPTS[@]}" -X POST "${BASE_URL}/auth/register" \
      -H 'Content-Type: application/json' \
      -d '{"email":"test@example.com","password":"secret123"}' >/dev/null 2>&1 || true
    token="$(curl "${CURL_OPTS[@]}" -f -X POST "${BASE_URL}/auth/login" \
      -d 'username=test@example.com&password=secret123' \
      2>/dev/null | python3 -c "import json,sys; print(json.load(sys.stdin)['access_token'])" 2>/dev/null || true)"
    if [[ -n "${token}" ]] \
      && curl "${CURL_OPTS[@]}" -f -H "Authorization: Bearer ${token}" "${BASE_URL}/auth/me" >/dev/null 2>&1; then
      echo "${token}"
      return 0
    fi
    sleep 0.2
  done
  echo "FAIL could not obtain auth token after 8 attempts"
  exit 1
}
