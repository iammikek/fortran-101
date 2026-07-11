.PHONY: build run test docker \
	test-app test-auth test-categories \
	test-items-create test-items-read test-items-list \
	test-items-update test-items-delete test-items-validation test-items-stats

BASE_URL ?= http://127.0.0.1:8008
CONTAINER_NAME ?=

TEST_ENV = BASE_URL=$(BASE_URL) CONTAINER_NAME=$(CONTAINER_NAME)

build:
	fpm build --profile release

run: build
	APP_PORT=8008 ./build/*/app/fortran-101 2>/dev/null || APP_PORT=8008 fpm run --profile release

test:
	chmod +x scripts/test_api.sh scripts/tests/*.sh
	$(TEST_ENV) ./scripts/test_api.sh

test-app:
	chmod +x scripts/tests/*.sh
	$(TEST_ENV) ./scripts/tests/test_app.sh

test-auth:
	chmod +x scripts/tests/*.sh
	$(TEST_ENV) ./scripts/tests/test_auth.sh

test-categories:
	chmod +x scripts/tests/*.sh
	$(TEST_ENV) ./scripts/tests/test_categories.sh

test-items-create:
	chmod +x scripts/tests/*.sh
	$(TEST_ENV) ./scripts/tests/test_items_create.sh

test-items-read:
	chmod +x scripts/tests/*.sh
	$(TEST_ENV) ./scripts/tests/test_items_read.sh

test-items-list:
	chmod +x scripts/tests/*.sh
	$(TEST_ENV) ./scripts/tests/test_items_list.sh

test-items-update:
	chmod +x scripts/tests/*.sh
	$(TEST_ENV) ./scripts/tests/test_items_update.sh

test-items-delete:
	chmod +x scripts/tests/*.sh
	$(TEST_ENV) ./scripts/tests/test_items_delete.sh

test-items-validation:
	chmod +x scripts/tests/*.sh
	$(TEST_ENV) ./scripts/tests/test_items_validation.sh

test-items-stats:
	chmod +x scripts/tests/*.sh
	$(TEST_ENV) ./scripts/tests/test_items_stats.sh

docker:
	docker compose up --build
