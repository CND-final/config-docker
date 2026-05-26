SOURCE_REPO   ?= https://github.com/CND-final/config-man.git
SOURCE_BRANCH ?= main
SOURCE_DIR    := base/config-man

.PHONY: help fetch-sources clean-sources build pull up up-build down logs

help:
	@echo "fetch-sources / build / pull / up / up-build / down / logs / clean-sources"

fetch-sources:
	@if [ ! -d "$(SOURCE_DIR)" ]; then \
		mkdir -p base && cd base && git clone --branch $(SOURCE_BRANCH) $(SOURCE_REPO); \
	else \
		cd $(SOURCE_DIR) && git pull origin $(SOURCE_BRANCH); \
	fi

build: fetch-sources
	docker compose -f docker-compose-build.yaml build

pull:
	docker compose pull

up:
	docker compose up -d

up-build: build
	docker compose -f docker-compose-build.yaml up -d

down:
	-docker compose -f docker-compose-build.yaml down
	-docker compose down

logs:
	docker compose logs -f

clean-sources:
	rm -rf $(SOURCE_DIR)
