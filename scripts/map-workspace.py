import fcntl
import hashlib
import os
import shutil
import stat
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MAPS = ROOT / "maps"
KIT = ROOT / "tools/map-starter-kit"
MARKER = KIT / ".self-hosted-map-workspace"
DIRECTORIES = {"src", "tilesets", "public", "assets"}
EXTENSIONS = {".tmj", ".tsj", ".png", ".jpg", ".jpeg", ".webp"}


def git(directory, *args):
    return subprocess.check_output(["git", "-C", directory, *args])


def managed(path):
    return (path.parts[0] in DIRECTORIES or
            (len(path.parts) == 1 and (path.suffix in EXTENSIONS or path.name.startswith("LICENSE."))))


def entries(directory):
    return sorted(p for p in directory.iterdir() if managed(Path(p.name)))


def remove(path):
    if path.is_symlink() or not path.is_dir():
        path.unlink()
    else:
        shutil.rmtree(path)


def replace_content(source, destination):
    for path in entries(destination):
        remove(path)
    for path in entries(source):
        target = destination / path.name
        if path.is_dir() and not path.is_symlink():
            shutil.copytree(path, target, symlinks=True)
        else:
            shutil.copy2(path, target, follow_symlinks=False)


def require_map(directory):
    if not any(p.is_file() for p in directory.glob("*.tmj")):
        raise ValueError(f"No .tmj map exists in {directory}")


def content_version(directory, *, map_paths=True):
    # Hash the saved paths, including uncommitted content, symlinks and executable bits.
    digest = hashlib.sha256()

    def visit(path):
        mode = path.lstat().st_mode
        digest.update(os.fsencode(path.relative_to(directory)) + b"\0")
        digest.update(str(mode).encode() + b"\0")
        if stat.S_ISLNK(mode):
            digest.update(os.fsencode(os.readlink(path)) + b"\0")
        elif stat.S_ISDIR(mode):
            for child in sorted(path.iterdir()):
                visit(child)
        elif stat.S_ISREG(mode):
            file_hash = hashlib.sha256()
            with path.open("rb") as stream:
                for chunk in iter(lambda: stream.read(1024 * 1024), b""):
                    file_hash.update(chunk)
            digest.update(file_hash.digest())
        else:
            raise ValueError(f"Unsupported map asset: {path}")

    for path in sorted(directory.iterdir()):
        if managed(Path(path.name)) == map_paths:
            visit(path)
    return digest.hexdigest()


def dirty_paths():
    status = git(KIT, "status", "--porcelain=v1", "-z", "--no-renames", "--untracked-files=all")
    return [Path(os.fsdecode(row[3:])) for row in status.split(b"\0") if row]


def map_pathspecs():
    return [*sorted(DIRECTORIES), ":(top,glob)LICENSE.*",
            *[f":(top,glob)*{ext}" for ext in sorted(EXTENSIONS)]]


def ignored_assets():
    ignored = git(KIT, "ls-files", "-z", "--others", "--ignored", "--exclude-standard", "--", *map_pathspecs())
    return [Path(os.fsdecode(p)) for p in ignored.split(b"\0") if p and managed(Path(os.fsdecode(p)))]


def prepare():
    require_map(MAPS)
    if MARKER.is_file():
        print("Map workspace is already prepared.")
        return
    if dirty_paths() or ignored_assets():
        raise ValueError("Back up, stash or commit local Starter Kit changes before preparing.")
    revision = content_version(MAPS)
    replace_content(MAPS, KIT)
    if content_version(KIT) != revision:
        raise ValueError("Map content changed during preparation. Check both copies before continuing.")
    MARKER.write_text(revision + "\n")
    print("Prepared map content in tools/map-starter-kit.")


def clean():
    git(KIT, "reset", "--hard", "HEAD")
    git(KIT, "clean", "-fd")
    if (KIT / "dist").exists():
        remove(KIT / "dist")


def save():
    if not MARKER.is_file():
        raise ValueError("Run make wa-prepare before saving.")
    require_map(KIT)
    outside = [p for p in dirty_paths() if p != Path(MARKER.name) and not managed(p)]
    if outside:
        raise ValueError("Back up or commit changes outside map content before saving: " +
                         ", ".join(map(str, outside)))
    baseline = MARKER.read_text().strip()
    if not baseline:
        raise ValueError("This workspace predates change tracking. Back up your edits before cleaning and preparing again.")
    if content_version(MAPS) != baseline:
        raise ValueError("maps/ changed since preparation. Reconcile both copies before saving.")

    # Stage on the same volume. Preserve files outside the managed set, including maps/.env.
    stage = Path(tempfile.mkdtemp(prefix=".map-save-", dir=ROOT))
    backup = stage / "original"
    replacement = stage / "replacement"
    try:
        shutil.copytree(MAPS, replacement, symlinks=True)
        replace_content(KIT, replacement)
        require_map(replacement)
        preserved = content_version(replacement, map_paths=False)
        MAPS.rename(backup)
        try:
            if content_version(backup) != baseline or content_version(backup, map_paths=False) != preserved:
                raise ValueError("maps/ changed during save. Reconcile both copies before saving.")
            replacement.rename(MAPS)
        except BaseException:
            backup.rename(MAPS)
            raise
        # A cleanup failure leaves the new map and the previous contents recoverable.
        if content_version(KIT) != content_version(MAPS):
            raise ValueError("Starter Kit changed during save. Your edits are still in the workspace.")
        # Restore only published assets. Other files, including build output, stay in place.
        paths = map_pathspecs()
        git(KIT, "reset", "--quiet", "HEAD", "--", *paths)
        tracked = git(KIT, "ls-files", "-z", "--", *paths)
        for path in entries(KIT):
            remove(path)
        subprocess.run(["git", "-C", KIT, "checkout-index", "--stdin", "-z"],
                       input=tracked, check=True)
        MARKER.unlink()
        shutil.rmtree(backup)
    finally:
        if backup.exists():
            print(f"Previous maps retained at {backup}", file=sys.stderr)
        else:
            shutil.rmtree(stage)
    print("Saved map content to maps/ and cleaned the Starter Kit workspace.")


def main():
    command, *args = sys.argv[1:]
    gitdir = Path(os.fsdecode(git(ROOT, "rev-parse", "--absolute-git-dir")).strip())
    with (gitdir / "map-workspace.lock").open("a") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            raise ValueError("Another map workspace operation is running.") from None
        if command == "init":
            subprocess.run(["npm", "ci"], cwd=ROOT, check=True)
            git(ROOT, "submodule", "update", "--init", "--recursive")
            subprocess.run(["npm", "ci"], cwd=KIT, check=True)
            return
        if Path(os.fsdecode(git(KIT, "rev-parse", "--show-toplevel")).strip()) != KIT:
            raise ValueError("Map Starter Kit submodule is not initialized. Run make wa-init.")
        if command == "prepare":
            prepare()
        elif command == "save":
            save()
        elif command == "clean":
            clean()
            print("Discarded temporary map workspace changes.")
        elif command == "update":
            if MARKER.exists() or dirty_paths():
                raise ValueError("Save or discard map workspace changes before updating the Starter Kit.")
            git(ROOT, "submodule", "update", "--remote", "--checkout", "tools/map-starter-kit")
            if args == ["--install"]:
                subprocess.run(["npm", "ci"], cwd=KIT, check=True)
            print("Updated the Starter Kit. Review and commit the new submodule revision.")
        elif command == "status":
            if MARKER.is_file():
                state = "prepared"
            else:
                state = "dirty" if dirty_paths() or ignored_assets() else "clean"
            print(f"workspace={state}", flush=True)
            subprocess.run(["git", "-C", KIT, "status", "--short"], check=True)
        elif command == "run" and args:
            prepare()
            subprocess.run(args, cwd=ROOT, check=True)
        else:
            raise ValueError("Expected prepare, save, clean, update, status, init or run COMMAND.")


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, subprocess.CalledProcessError) as error:
        sys.exit(f"ERROR: {error}")
