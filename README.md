# fortran-101

A minimal **API-only** Fortran application in the *-101 family. It mirrors the JSON API contract of [fastAPI-101](https://github.com/iammikek/fastAPI-101) with JWT auth, SQLite persistence, and bash feature tests — but **no server-rendered shop UI**.

## API-only by design

Like [go-101](https://github.com/iammikek/go-101), [nest-101](https://github.com/iammikek/nest-101), and [express-101](https://github.com/iammikek/express-101), this repo has **no server-rendered shop**. Pair it with [react-101](https://github.com/iammikek/react-101), [vue-101](https://github.com/iammikek/vue-101), [alpine-101](https://github.com/iammikek/alpine-101), or [flutter-101](https://github.com/iammikek/flutter-101).

**Why Fortran?** Uncommon for web APIs — but useful for learning how HTTP, JSON, and persistence look when you already think in modules, arrays, and explicit memory.

## What's included

- Fortran REST API on port **8008** (fpm + gfortran)
- POSIX HTTP server via `iso_c_binding` (no nginx/Apache)
- SQLite via `sqlite3` C API
- JWT authentication (OpenSSL HMAC-SHA256 + libcrypt passwords)
- Services: user, category, and item persistence in `app_db`
- Domain errors with `{ detail, code }` responses
- Pagination: `{ items, total, skip, limit }` plus item filters
- **47 bash feature tests** (parity with fastAPI-101 integration suite)
- Dockerfile, docker-compose, GitHub Actions CI, Makefile

## Quick start

```bash
cp .env.example .env
docker compose up --build
```

Open **http://127.0.0.1:8008** — you should see:

```json
{"message":"Hello from fortran-101"}
```

### Local (requires gfortran + fpm)

```bash
make build
APP_PORT=8008 ./build/*/app/fortran-101
```

### Tests

```bash
# server must be running on 8008 (or use docker — see below)
make test

# run one module (server must be running)
make test-auth
make test-items-list

# or invoke scripts directly
chmod +x scripts/tests/*.sh
CONTAINER_NAME=fortran-101-test BASE_URL=http://127.0.0.1:8008 ./scripts/tests/test_auth.sh
```

## API endpoints

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | `/` | — | Hello message |
| GET | `/health` | — | Health check |
| POST | `/auth/register` | — | Register user |
| POST | `/auth/login` | — | Login (form or JSON) |
| GET | `/auth/me` | JWT | Current user |
| GET | `/categories` | — | List categories |
| GET | `/categories/:id` | — | Show category |
| POST/PATCH/DELETE | `/categories` | JWT | Manage categories |
| GET | `/items` | — | List items (paginated, filterable) |
| GET | `/items/stats/summary` | — | Item statistics |
| GET | `/items/:id` | — | Show item |
| POST/PATCH/DELETE | `/items` | JWT | Manage items |

Write operations require `Authorization: Bearer <token>`.

## Environment variables

| Variable | Default | Description |
|----------|---------|-------------|
| `APP_PORT` | `8008` | Listen port |
| `APP_HOST` | `0.0.0.0` | Bind address (informational) |
| `DB_DATABASE` | `database/database.sqlite` | SQLite file path |
| `JWT_SECRET` | `change-me-in-production` | JWT signing secret |

## Project structure

```
fortran-101/
├── fpm.toml
├── src/
│   ├── app.f90           # main
│   ├── http_server.f90   # POSIX server + request parsing
│   ├── api_router.f90    # routes, validation, handlers
│   ├── app_db.f90        # SQLite services
│   ├── chelpers.c        # JWT, password hash, sqlite bind helpers
│   └── ...
├── database/schema.sql
├── scripts/
│   ├── test_api.sh       # runs all feature tests
│   └── tests/            # fastAPI-101 parity (one script per area)
│       ├── common.sh
│       ├── test_app.sh
│       ├── test_auth.sh
│       ├── test_categories.sh
│       ├── test_items_create.sh
│       ├── test_items_read.sh
│       ├── test_items_list.sh
│       ├── test_items_update.sh
│       ├── test_items_delete.sh
│       ├── test_items_validation.sh
│       └── test_items_stats.sh
├── Dockerfile
└── .github/workflows/ci.yml
```

## Docker

```bash
docker compose up --build
```

The API listens on **http://localhost:8008**.

## Tests

47 feature tests cover health, auth, categories, items (CRUD, filters, stats, validation) — ported from fastAPI-101's pytest integration suite. Tests are split under `scripts/tests/` (mirroring `fastAPI-101/tests/` file names):

```bash
make test                              # run full suite (47 tests)
make test-items-list                   # run one module
make test-auth                         # auth module only

# with docker (enables reset_db between cases)
docker build -t fortran-101:test .
docker run -d --name fortran-101-test -p 8008:8008 fortran-101:test
CONTAINER_NAME=fortran-101-test make test
```

## *-101 Family

Full family list, ports, and clone-with-submodules: **[learning-101](https://github.com/iammikek/learning-101)**. Site catalogue: [automica.io/learning-101](https://automica.io/learning-101.html).
