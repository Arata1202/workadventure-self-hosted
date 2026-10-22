#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MAPS_DIR="$ROOT_DIR/maps"
TOOL_DIR="$ROOT_DIR/tools/map-starter-kit"
MARKER="$TOOL_DIR/.self-hosted-map-workspace"

usage() {
  echo "Usage: $0 <prepare|save|clean|update|status>" >&2
  exit 2
}

require_submodule() {
  local tool_root
  tool_root="$(git -C "$TOOL_DIR" rev-parse --show-toplevel 2>/dev/null || true)"
  if [[ -z "$tool_root" || "$(cd "$tool_root" && pwd -P)" != "$(cd "$TOOL_DIR" && pwd -P)" ]]; then
    echo "ERROR: Map Starter Kit submodule is not initialized." >&2
    echo "Run: make wa-init" >&2
    exit 1
  fi
}

clear_content() {
  local directory="$1"
  find "$directory" -maxdepth 1 -type f \
    \( -name '*.tmj' -o -name '*.tsj' -o -name '*.png' -o -name '*.jpg' -o -name '*.jpeg' -o -name '*.webp' -o -name 'LICENSE.*' \) \
    -delete
  rm -rf "$directory/src" "$directory/tilesets" "$directory/public" "$directory/assets"
}

copy_content() {
  local source="$1"
  local destination="$2"
  find "$source" -maxdepth 1 -type f \
    \( -name '*.tmj' -o -name '*.tsj' -o -name '*.png' -o -name '*.jpg' -o -name '*.jpeg' -o -name '*.webp' -o -name 'LICENSE.*' \) \
    -exec cp -p {} "$destination/" \;
  for name in src tilesets public assets; do
    if [[ -d "$source/$name" ]]; then
      cp -a "$source/$name" "$destination/$name"
    fi
  done
}

require_map() {
  local directory="$1"
  if ! find "$directory" -maxdepth 1 -type f -name '*.tmj' -print -quit | grep -q .; then
    echo "ERROR: No .tmj map exists in $directory." >&2
    exit 1
  fi
}

clean_tool() {
  git -C "$TOOL_DIR" reset --hard HEAD >/dev/null
  git -C "$TOOL_DIR" clean -fd >/dev/null
  rm -rf "$TOOL_DIR/dist"
}

prepare() {
  require_submodule
  require_map "$MAPS_DIR"
  if [[ -f "$MARKER" ]]; then
    echo "Map workspace is already prepared."
    return
  fi
  if [[ -n "$(git -C "$TOOL_DIR" status --porcelain --untracked-files=all)" ]]; then
    echo "ERROR: Map Starter Kit has unsaved changes." >&2
    echo "Run 'make wa-save' to keep map changes or 'make wa-clean' to discard them." >&2
    exit 1
  fi
  clear_content "$TOOL_DIR"
  copy_content "$MAPS_DIR" "$TOOL_DIR"
  touch "$MARKER"
  echo "Prepared map content in tools/map-starter-kit."
}

save() {
  require_submodule
  if [[ ! -f "$MARKER" ]]; then
    echo "ERROR: Map workspace is not prepared." >&2
    echo "Run: make wa-prepare" >&2
    exit 1
  fi
  require_map "$TOOL_DIR"
  local temporary
  temporary="$(mktemp -d)"
  trap "rm -rf '$temporary'" EXIT
  copy_content "$TOOL_DIR" "$temporary"
  require_map "$temporary"
  clear_content "$MAPS_DIR"
  copy_content "$temporary" "$MAPS_DIR"
  clean_tool
  echo "Saved map content to maps/ and cleaned the Starter Kit workspace."
}

clean() {
  require_submodule
  clean_tool
  echo "Discarded temporary map workspace changes."
}

update() {
  require_submodule
  if [[ -f "$MARKER" || -n "$(git -C "$TOOL_DIR" status --porcelain --untracked-files=all)" ]]; then
    echo "ERROR: Save or discard map workspace changes before updating the Starter Kit." >&2
    exit 1
  fi
  git -C "$ROOT_DIR" submodule update --remote --checkout tools/map-starter-kit
  echo "Updated the Map Starter Kit submodule. Commit the new submodule revision after verification."
}

status() {
  require_submodule
  if [[ -f "$MARKER" ]]; then echo "workspace=prepared"; else echo "workspace=clean"; fi
  git -C "$TOOL_DIR" status --short
}

case "${1:-}" in
  prepare) prepare ;;
  save) save ;;
  clean) clean ;;
  update) update ;;
  status) status ;;
  *) usage ;;
esac
