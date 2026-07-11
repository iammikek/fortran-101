# Getting Fast at Fortran

A step-by-step **Fortran + fpm** port of [fastAPI-101](https://github.com/iammikek/fastAPI-101) — same items/categories JSON API, same Laravel crossover style, compiled backend on port **8008**.

**Audience:** Fortran developers (or HPC engineers) learning how a Laravel-style REST API maps to modern Fortran with `iso_c_binding`, POSIX sockets, and SQLite.

**API-only:** Like [go-101](https://github.com/iammikek/go-101), [nest-101](https://github.com/iammikek/nest-101), and [express-101](https://github.com/iammikek/express-101), this repo has **no server-rendered shop**. Pair it with [react-101](https://github.com/iammikek/react-101), [vue-101](https://github.com/iammikek/vue-101), or [flutter-101](https://github.com/iammikek/flutter-101).

**Why Fortran?** Uncommon for web APIs — but useful for learning how HTTP, JSON, and persistence look when you already think in arrays, modules, and explicit memory. Production teams usually keep Fortran for numerics and expose it via a thin Python/Go layer; this project shows the full stack in Fortran anyway.

---

## What's Included (today)

1. **fpm** — Fortran Package Manager build (`fpm.toml`)
2. **POSIX HTTP server** — pure Fortran + `iso_c_binding` to BSD sockets (no Apache/nginx)
3. **JSON responses** — hand-built strings matching the *-101 contract
4. **Read routes** — `/`, `/health`, `/categories`, `/items`, `/items/stats/summary`
5. **Docker** — `gfortran` + fpm image on port **8008**
6. **CI** — GitHub Actions builds the image and runs curl smoke tests
7. **Schema** — `database/schema.sql` ready for SQLite wiring

### Roadmap (next steps in README tutorial)

8. SQLite persistence via `sqlite3` C API
9. JWT auth (`/auth/register`, `/auth/login`, `/auth/me`)
10. Category + item CRUD with `{ detail, code }` errors
11. Pagination filters on `GET /items`
12. **19 feature tests** — parity with [express-101](https://github.com/iammikek/express-101)

---

## Quick Start

### Docker (recommended)

```bash
cd fortran-101
docker compose up --build
```

Open **http://localhost:8008/** — hello JSON  
**http://localhost:8008/health** — `{ "status": "ok" }`  
**http://localhost:8008/items** — empty paginated list

### Local (requires gfortran + fpm)

```bash
cp .env.example .env
curl -fsSL https://github.com/fortran-lang/fpm/releases/download/v0.13.0/fpm-0.13.0-$(uname -s | tr '[:upper:]' '[:lower:]')-$(uname -m) -o ~/.local/bin/fpm
chmod +x ~/.local/bin/fpm
make build
APP_PORT=8008 ./build/release/fortran-101
```

### Tests

```bash
# server must be running on 8008
make test
```

---

## Project Structure

```
fortran-101/
├── fpm.toml
├── src/
│   └── app.f90          # http_types, http_server, api_router, main
├── database/
│   └── schema.sql       # users, categories, items
├── scripts/
│   └── test_api.sh    # curl smoke tests
├── Dockerfile
├── docker-compose.yml
└── .github/workflows/ci.yml
```

---

## Laravel → Fortran Mapping

| Laravel | fortran-101 |
|---------|-------------|
| `routes/api.php` | `route_request` in `api_router` |
| `FormRequest` validation | explicit checks in handlers (planned) |
| Eloquent models | derived types + SQLite queries (planned) |
| Sanctum JWT | OpenSSL HMAC JWT module (planned) |
| `paginate()` | `{ items, total, skip, limit }` JSON |
| Blade `/shop` | not applicable (API-only) |

---

## API Endpoints (client coverage)

| Path | Method | Auth | Status |
|------|--------|------|--------|
| `/` | GET | — | Implemented |
| `/health` | GET | — | Implemented |
| `/categories` | GET | — | Implemented (empty list) |
| `/items` | GET | — | Implemented (empty list) |
| `/items/stats/summary` | GET | — | Implemented (zeros) |
| `/auth/register` | POST | — | Planned |
| `/auth/login` | POST | — | Planned |
| `/auth/me` | GET | JWT | Planned |
| `/categories` | POST | JWT | Planned |
| `/categories/{id}` | GET/PATCH/DELETE | JWT on writes | Planned |
| `/items` | POST | JWT | Planned |
| `/items/{id}` | GET/PATCH/DELETE | JWT on writes | Planned |

---

## *-101 Family

### API backends

| Repo | Port | Type | Stack |
|------|------|------|-------|
| [fastAPI-101](https://github.com/iammikek/fastAPI-101) | 8000 | API-only | FastAPI, SQLAlchemy |
| [django-101](https://github.com/iammikek/django-101) | 8001 | Monolith | Django + DRF + shop |
| [symfony-101](https://github.com/iammikek/symfony-101) | 8002 | Monolith | Symfony + shop |
| [laravel-101](https://github.com/iammikek/laravel-101) | 8003 | Monolith | Laravel + shop |
| [framework-x-101](https://github.com/iammikek/framework-x-101) | 8004 | Monolith | Framework X + shop |
| [orchestr-101](https://github.com/iammikek/orchestr-101) | 8005 | Monolith | Orchestr + shop |
| [nest-101](https://github.com/iammikek/nest-101) | 8006 | API-only | NestJS, TypeScript |
| [express-101](https://github.com/iammikek/express-101) | 8007 | API-only | Express, Vitest |
| [go-101](https://github.com/iammikek/go-101) | 8000* | API-only | Gin, GORM |
| [**fortran-101**](https://github.com/iammikek/fortran-101) | **8008** | API-only | Fortran, fpm, SQLite |

\* go-101 also uses port 8000 — run one backend at a time, or change port in config.

### Other clients

| Repo | Platform | Stack |
|------|----------|-------|
| [flutter-101](https://github.com/iammikek/flutter-101) | Mobile / desktop | Flutter (iOS, macOS, Android) |
| [react-101](https://github.com/iammikek/react-101) | Web browser | React 19, Vite, Vitest |
| [vue-101](https://github.com/iammikek/vue-101) | Web browser | Vue 3, Vite, Pinia |

### Suggested pairing

- **Learning the API:** [fastAPI-101](https://github.com/iammikek/fastAPI-101) (8000) + [react-101](https://github.com/iammikek/react-101)
- **Compare compiled backends:** fortran-101 (8008) vs [go-101](https://github.com/iammikek/go-101)
- **Compare Node APIs:** [nest-101](https://github.com/iammikek/nest-101) (8006) or [express-101](https://github.com/iammikek/express-101) (8007)

Catalogue: [automica.io/learning-101](https://automica.io/learning-101.html)

---

## Quick Reference

| Goal | Command |
|------|---------|
| Copy env | `cp .env.example .env` |
| Build | `make build` or `fpm build --profile release` |
| Run | `APP_PORT=8008 ./build/release/fortran-101` |
| Docker | `docker compose up --build` |
| Smoke tests | `make test` |
| Default port | **8008** |

---

## Compare with go-101

| | go-101 | fortran-101 |
|--|--------|-------------|
| Port | 8000 | 8008 |
| HTTP | Gin router | POSIX sockets + manual routing |
| ORM | GORM | SQLite C API (planned) |
| JSON | encoding/json | hand-built strings |
| Tests | testify (19+) | curl smoke tests (5 today; 19 planned) |
| Typical use | microservices | HPC / numerics crossover |

Same JSON shapes. Same tutorial intent. Different language ergonomics.
