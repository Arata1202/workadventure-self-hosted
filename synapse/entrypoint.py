#!/usr/local/bin/python
"""Render Synapse's configuration, then hand startup to the image entrypoint."""

import json
import os
import re
import sys
from pathlib import Path
from tempfile import NamedTemporaryFile

import yaml


def substitute(match):
    name = match[1]
    value = os.environ.get(name)
    if not value:
        sys.exit(f"{name} is required")
    # The claim is also a string literal inside Synapse's Jinja mapping.
    return json.dumps(value) if name == "OPENID_USERNAME_CLAIM" else value


def render(value):
    if isinstance(value, str):
        return re.sub(r"\$\{([A-Z_]+)\}", substitute, value)
    if isinstance(value, dict):
        return {key: render(item) for key, item in value.items()}
    if isinstance(value, list):
        return [render(item) for item in value]
    return value


def write_config(template, destination):
    config = render(yaml.safe_load(template.read_text()))
    output = NamedTemporaryFile(mode="w", dir=destination.parent, delete=False)
    temporary = Path(output.name)
    try:
        with output:
            yaml.safe_dump(config, output, sort_keys=False)
            if os.getuid() == 0:
                # Match the UID/GID used by the upstream /start.py privilege drop.
                uid = int(os.environ.get("UID", "991"))
                gid = int(os.environ.get("GID", "991")) if "UID" in os.environ else 991
                os.fchown(output.fileno(), uid, gid)
        temporary.replace(destination)
    finally:
        temporary.unlink(missing_ok=True)


if __name__ == "__main__":
    write_config(Path("/homeserver.template.yaml"), Path("/data/homeserver.yaml"))
    os.execv("/start.py", ["/start.py", *sys.argv[1:]])
