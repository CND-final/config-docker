# Registry / image configuration
# All variables can be overridden via environment or make CLI, e.g.:
#   make build TAG=v1.2.3
#   REGISTRY=ghcr.io NAMESPACE=cnd-final make push
REGISTRY  ?= ghcr.io
NAMESPACE ?= cnd-final
TAG       ?= latest
MKCERT_IMAGE ?= alpine:3.20
MKCERT_URL   ?= https://dl.filippo.io/mkcert/latest?for=
MKCERT_DIR   ?= certs/mkcert

BACKEND_IMAGE  = $(REGISTRY)/$(NAMESPACE)/config-man-backend:$(TAG)
FRONTEND_IMAGE = $(REGISTRY)/$(NAMESPACE)/config-man-frontend:$(TAG)

# Source repo for config-man application code
SOURCE_REPO   ?= https://github.com/CND-final/config-man.git
SOURCE_BRANCH ?= main
SOURCE_DIR    := base/config-man

.PHONY: help fetch-sources clean-sources build push pull certs up up-build down logs init-config

help:
	@echo "Usage: make <target>"
	@echo ""
	@echo "  fetch-sources   clone or update config-man source into $(SOURCE_DIR)"
	@echo "  build           build backend + frontend images tagged for GHCR"
	@echo "  push            push both images to $(REGISTRY)/$(NAMESPACE)"
	@echo "  pull            pull images from registry (docker-compose.yaml)"
	@echo "  certs           generate local TLS certs with mkcert (containerized)"
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

certs:
	@mkdir -p certs $(MKCERT_DIR)
	@docker run --rm \
	  -v "$(CURDIR)/certs:/certs" \
	  -v "$(CURDIR)/$(MKCERT_DIR):/root/.local/share/mkcert" \
	  $(MKCERT_IMAGE) \
	  /bin/sh -c 'set -e; apk add --no-cache curl ca-certificates >/dev/null; arch="$$(uname -m)"; \
	    case "$$arch" in \
	      x86_64) platform="linux/amd64" ;; \
	      aarch64) platform="linux/arm64" ;; \
	      *) echo "Unsupported arch: $$arch" >&2; exit 1 ;; \
	    esac; \
	    curl -fsSL "$(MKCERT_URL)$${platform}" -o /usr/local/bin/mkcert; \
	    chmod +x /usr/local/bin/mkcert; \
	    /usr/local/bin/mkcert -cert-file /certs/fullchain.pem -key-file /certs/privkey.pem localhost 127.0.0.1 ::1'

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
