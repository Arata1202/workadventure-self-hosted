DR := npx dotenvx run --

define REQUIRED_P
	@set -e; \
	if [ -z "$(strip $(P))" ]; then \
		echo ""; \
		echo "ERROR: Missing required P."; \
		echo "Usage: make $(MAKECMDGOALS) P=<TARGET>"; \
		exit 1; \
	fi
endef

define OPTIONAL_P
	@set -e; \
	if [ -z "$(strip $(P))" ]; then \
		echo ""; \
		echo "WARN: P is empty. This will run on ALL services."; \
		echo "Tip: make $(MAKECMDGOALS) P=<TARGET>"; \
		echo ""; \
		printf "Proceed? [y/N] "; \
		read ans; \
		echo ""; \
		case "$$ans" in \
			y|Y|yes|YES) ;; \
			*) echo "Aborted"; exit 1 ;; \
		esac; \
	fi
endef

# Docker

DC := docker compose

exec:
	$(REQUIRED_P)
	@${DR} ${DC} exec $(P) bash

up:
	$(OPTIONAL_P)
	@${DR} ${DC} up -d $(P)

up-f:
	$(OPTIONAL_P)
	@${DR} ${DC} up -d --force-recreate $(P)

stop:
	$(OPTIONAL_P)
	@${DR} ${DC} stop $(P)

restart:
	$(OPTIONAL_P)
	@${DR} ${DC} restart $(P)

logs:
	$(OPTIONAL_P)
	@${DR} ${DC} logs -f $(P)

ps:
	$(OPTIONAL_P)
	@${DR} ${DC} ps -a $(P)

# Dotenvx

encrypt:
	@npx dotenvx encrypt

decrypt:
	@npx dotenvx decrypt

# WorkAdventure
MAP_TOOL := tools/map-starter-kit
MAP_ENV := maps/.env
MAP_DR := npx dotenvx run -f ${MAP_ENV} --

wa-init:
	@npm ci
	@git submodule update --init --recursive
	@cd ${MAP_TOOL} && npm ci

wa-prepare:
	@./scripts/map-workspace.sh prepare

wa-dev: wa-prepare
	@${MAP_DR} npm --prefix ${MAP_TOOL} run dev

wa-build: wa-prepare
	@cd ${MAP_TOOL} && npm run buildmap

wa-upload: wa-prepare
	@${MAP_DR} npm --prefix ${MAP_TOOL} run upload

wa-save:
	@./scripts/map-workspace.sh save

wa-clean:
	@./scripts/map-workspace.sh clean

wa-update:
	@./scripts/map-workspace.sh update
	@cd ${MAP_TOOL} && npm ci

wa-status:
	@./scripts/map-workspace.sh status

.PHONY: exec up up-f stop restart logs ps encrypt decrypt wa-init wa-prepare wa-dev wa-build wa-upload wa-save wa-clean wa-update wa-status
