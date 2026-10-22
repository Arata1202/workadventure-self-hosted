# Map content

This directory is the source of truth for the WorkAdventure maps deployed by this repository.

The official [WorkAdventure Map Starter Kit](https://github.com/workadventure/map-starter-kit) is pinned as a submodule at `tools/map-starter-kit/` and used only as the development, build, and upload workspace.

## Workflow

```bash
# Initialize the official Starter Kit and its dependencies
make wa-init

# Copy the tracked map content into the Starter Kit workspace
make wa-prepare

# Start the official development server, then edit files under tools/map-starter-kit/
make wa-dev

# Save edited map content back here and clean the submodule
make wa-save
```

Use `make wa-clean` to discard temporary workspace changes instead. Do not commit changes inside the official submodule.

The synchronization includes top-level map and image files, the license files, and the optional `src/`, `tilesets/`, `public/`, and `assets/` directories.
