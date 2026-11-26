import importlib.util
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
from unittest.mock import patch


SOURCE = Path(__file__).resolve().parents[1] / "scripts"
spec = importlib.util.spec_from_file_location("workspace", SOURCE / "map-workspace.py")
workspace = importlib.util.module_from_spec(spec)
spec.loader.exec_module(workspace)


class WorkspaceTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="map' workspace ")
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name).resolve()
        self.maps = self.root / "maps"
        self.kit = self.root / "tools/map-starter-kit"
        self.maps.mkdir()
        self.kit.mkdir(parents=True)
        self.marker = self.kit / workspace.MARKER.name
        for directory in [self.root, self.kit]:
            subprocess.run(["git", "init", "-q", directory], check=True)
        (self.kit / "initial.tmj").write_text("upstream")
        (self.kit / ".gitignore").write_text("*.cache\ndist/\n")
        workspace.git(self.kit, "add", ".")
        workspace.git(self.kit, "-c", "user.name=test", "-c", "user.email=test@example.invalid",
                      "-c", "commit.gpgsign=false", "-c", "core.hooksPath=/dev/null", "commit", "-qm", "init")
        (self.maps / "office.tmj").write_text("original")
        (self.maps / ".env").write_text("local")
        overrides = patch.multiple(workspace, ROOT=self.root, MAPS=self.maps, KIT=self.kit, MARKER=self.marker)
        overrides.start()
        self.addCleanup(overrides.stop)

    def test_save_keeps_unmanaged_files(self):
        workspace.prepare()
        (self.kit / "office.tmj").write_text("new map")
        (self.kit / "dist").mkdir()
        (self.kit / "dist/operator-note").write_text("keep")
        workspace.save()
        self.assertEqual((self.kit / "dist/operator-note").read_text(), "keep")
        self.assertEqual((self.maps / "office.tmj").read_text(), "new map")
        self.assertEqual((self.maps / ".env").read_text(), "local")
        self.assertEqual(workspace.dirty_paths(), [])

    def test_independent_destination_edit(self):
        workspace.prepare()
        (self.maps / "office.tmj").write_text("direct edit")
        with self.assertRaisesRegex(ValueError, "changed since preparation"):
            workspace.save()
        self.assertEqual((self.maps / "office.tmj").read_text(), "direct edit")
        self.assertTrue(self.marker.exists())

    def test_ignored_asset_and_unsupported_source(self):
        (self.kit / "src").mkdir()
        ignored = self.kit / "src/custom.cache"
        ignored.write_text("local")
        with self.assertRaisesRegex(ValueError, "Back up"):
            workspace.prepare()
        self.assertTrue(ignored.exists())
        ignored.unlink()
        workspace.prepare()
        (self.kit / "sound.mp3").write_bytes(b"audio")
        with self.assertRaisesRegex(ValueError, "sound.mp3"):
            workspace.save()
        self.assertTrue((self.kit / "sound.mp3").exists())

    def test_failed_copy_and_publish_preserve_both_copies(self):
        workspace.prepare()
        (self.kit / "office.tmj").write_text("new map")
        with patch.object(workspace.shutil, "copy2", side_effect=OSError("copy failed")):
            with self.assertRaisesRegex(OSError, "copy failed"):
                workspace.save()
        rename = Path.rename

        def fail_replacement(source, target):
            if source.name == "replacement":
                raise OSError("publish failed")
            return rename(source, target)

        with patch.object(Path, "rename", fail_replacement):
            with self.assertRaisesRegex(OSError, "publish failed"):
                workspace.save()
        self.assertEqual((self.maps / "office.tmj").read_text(), "original")
        self.assertEqual((self.kit / "office.tmj").read_text(), "new map")

    def test_consumer_holds_workspace_lock(self):
        shutil.copytree(SOURCE, self.root / "scripts")
        command = [self.root / "scripts/map-workspace.sh"]
        with subprocess.Popen(command + ["run", "sh", "-c", "echo ready; read line"],
                              stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                              env={**os.environ, "PYTHONUNBUFFERED": "1"}) as process:
            try:
                while b"ready" not in (line := process.stdout.readline()):
                    self.assertTrue(line)
                attempted = subprocess.run(command + ["clean"], capture_output=True)
                self.assertNotEqual(attempted.returncode, 0)
                self.assertIn(b"Another map workspace operation", attempted.stderr)
                self.assertTrue(self.marker.exists())
            finally:
                process.communicate(b"continue\n")


if __name__ == "__main__":
    unittest.main()
