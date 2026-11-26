# Preserve the literal command-line value when exporting it to the shell.
override P := $(value P)
export P

exec up up-f stop restart logs ps:
	@./scripts/compose.sh $@

encrypt decrypt:
	@./scripts/dotenvx.sh $@

# WorkAdventure
MAP_TOOL := tools/map-starter-kit
MAP_ENV := maps/.env
MAP_DR := ./scripts/dotenvx.sh run -f ${MAP_ENV} --

wa-init:
	@./scripts/map-workspace.sh init

wa-prepare:
	@./scripts/map-workspace.sh prepare

wa-dev:
	@./scripts/map-workspace.sh run ${MAP_DR} npm --prefix ${MAP_TOOL} run dev

wa-build:
	@./scripts/map-workspace.sh run ${MAP_DR} npm --prefix ${MAP_TOOL} run buildmap

wa-upload:
	@./scripts/map-workspace.sh run ${MAP_DR} npm --prefix ${MAP_TOOL} run upload

wa-save:
	@./scripts/map-workspace.sh save

wa-clean:
	@./scripts/map-workspace.sh clean

wa-update:
	@./scripts/map-workspace.sh update --install

wa-status:
	@./scripts/map-workspace.sh status

.PHONY: exec up up-f stop restart logs ps encrypt decrypt wa-init wa-prepare wa-dev wa-build wa-upload wa-save wa-clean wa-update wa-status
