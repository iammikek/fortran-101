.PHONY: build run test docker

build:
	fpm build --profile release

run: build
	APP_PORT=8008 ./build/*/app/fortran-101 2>/dev/null || APP_PORT=8008 fpm run --profile release

test:
	chmod +x scripts/test_api.sh
	./scripts/test_api.sh

docker:
	docker compose up --build
