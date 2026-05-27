# Registry / image configuration
# All variables can be overridden via environment or make CLI, e.g.:
#   make build TAG=v1.2.3
#   REGISTRY=ghcr.io NAMESPACE=cnd-final make push
REGISTRY  ?= ghcr.io
NAMESPACE ?= cnd-final
TAG       ?= latest

BACKEND_IMAGE  = $(REGISTRY)/$(NAMESPACE)/config-man-backend:$(TAG)
FRONTEND_IMAGE = $(REGISTRY)/$(NAMESPACE)/config-man-frontend:$(TAG)

# Source repo for config-man application code
SOURCE_REPO   ?= https://github.com/CND-final/config-man.git
SOURCE_BRANCH ?= main
SOURCE_DIR    := base/config-man

.PHONY: help fetch-sources clean-sources build push pull up up-build down logs init-config

help:
	@echo "Usage: make <target>"
	@echo ""
	@echo "  fetch-sources   clone or update config-man source into $(SOURCE_DIR)"
	@echo "  build           build backend + frontend images tagged for GHCR"
	@echo "  push            push both images to $(REGISTRY)/$(NAMESPACE)"
	@echo "  pull            pull images from registry (docker-compose.yaml)"
	@echo "  up              start all services from registry images"
	@echo "  up-build        build from source and start all services (local dev)"
	@echo "  down            stop all services"
	@echo "  logs            stream logs from all services"
	@echo "  clean-sources   remove $(SOURCE_DIR)"
	@echo "  init-config     copy config/*.env.example to config/*.env if missing"
	@echo ""
	@echo "Variables (current values):"
	@echo "  REGISTRY  = $(REGISTRY)"
	@echo "  NAMESPACE = $(NAMESPACE)"
	@echo "  TAG       = $(TAG)"

fetch-sources:
	@if [ ! -d "$(SOURCE_DIR)" ]; then \
		mkdir -p base && cd base && git clone --branch $(SOURCE_BRANCH) $(SOURCE_REPO); \
	else \
		cd $(SOURCE_DIR) && git pull origin $(SOURCE_BRANCH); \
	fi

build: fetch-sources
	docker build -f backend/Dockerfile  -t $(BACKEND_IMAGE)  .
	docker build -f frontend/Dockerfile -t $(FRONTEND_IMAGE) .

push:
	docker push $(BACKEND_IMAGE)
	docker push $(FRONTEND_IMAGE)

pull:
	docker compose pull

init-config:
	@for f in postgres backend frontend; do \
	  if [ ! -f config/$$f.env ]; then \
	    cp config/$$f.env.example config/$$f.env; \
	    echo "Created config/$$f.env from example"; \
	  fi; \
	done

up: init-config
	docker compose up -d

up-build: init-config fetch-sources
	docker compose -f docker-compose-build.yaml up -d --build

down:
	-docker compose -f docker-compose-build.yaml down
	-docker compose down

logs:
	docker compose logs -f

clean-sources:
	rm -rf $(SOURCE_DIR)
