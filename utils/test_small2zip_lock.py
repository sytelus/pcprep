#!/usr/bin/env python3
"""Stdlib-only two-process regression test for small2zip archive ownership."""

from __future__ import annotations

import argparse
import multiprocessing
import sys
import types
import unittest
import zipfile
from pathlib import Path
from tempfile import TemporaryDirectory


class _RichPlaceholder:
    def __init__(self, *_args, **_kwargs):
        pass


# This focused safety test deliberately has no third-party dependency. The real
# unit suite exercises rendering when Rich is installed; process_folder below
# uses its own null progress object.
rich = types.ModuleType("rich")
rich_console = types.ModuleType("rich.console")
rich_logging = types.ModuleType("rich.logging")
rich_panel = types.ModuleType("rich.panel")
rich_progress = types.ModuleType("rich.progress")
rich_table = types.ModuleType("rich.table")
rich_console.Console = _RichPlaceholder
rich_console.Group = _RichPlaceholder
rich_logging.RichHandler = _RichPlaceholder
rich_panel.Panel = _RichPlaceholder
for name in (
    "BarColumn",
    "MofNCompleteColumn",
    "Progress",
    "SpinnerColumn",
    "TaskProgressColumn",
    "TextColumn",
    "TimeElapsedColumn",
    "TimeRemainingColumn",
):
    setattr(rich_progress, name, _RichPlaceholder)
rich_table.Table = _RichPlaceholder
sys.modules.update(
    {
        "rich": rich,
        "rich.console": rich_console,
        "rich.logging": rich_logging,
        "rich.panel": rich_panel,
        "rich.progress": rich_progress,
        "rich.table": rich_table,
    }
)

sys.path.insert(0, str(Path(__file__).resolve().parent))
import small2zip as s  # noqa: E402


class _NullProgress:
    def add_task(self, *_args, **_kwargs):
        return 0

    def update(self, *_args, **_kwargs):
        pass

    def advance(self, *_args, **_kwargs):
        pass

    def remove_task(self, *_args, **_kwargs):
        pass


def _hold_lock(lock_path: str, partial_path: str, ready, release) -> None:
    lock = s.ArchiveLock(Path(lock_path))
    lock.acquire()
    Path(partial_path).write_bytes(b"owned by first process")
    ready.set()
    release.wait(10)
    lock.release()


class TestCrossProcessLock(unittest.TestCase):
    def test_loser_cannot_touch_partial_archive_or_source(self) -> None:
        with TemporaryDirectory() as temp:
            root = Path(temp)
            folder = root / "d"
            folder.mkdir()
            source = folder / "important.txt"
            source.write_bytes(b"source must survive")
            lock_path = root / f"d{s.LOCK_SUFFIX}"
            partial_path = root / f"d{s.PARTIAL_SUFFIX}"
            ready = multiprocessing.Event()
            release = multiprocessing.Event()
            process = multiprocessing.Process(
                target=_hold_lock,
                args=(str(lock_path), str(partial_path), ready, release),
            )
            process.start()
            try:
                self.assertTrue(ready.wait(10), "lock holder did not start")
                args = argparse.Namespace(exists=False, verify="full", keep=False, dry_run=False)
                result = s.process_folder(
                    folder, args, zipfile.ZIP_STORED, None, _NullProgress()
                )
                self.assertEqual(result.status, "skipped", result.message)
                self.assertIn("archive lock already exists", result.message)
                self.assertEqual(partial_path.read_bytes(), b"owned by first process")
                self.assertEqual(source.read_bytes(), b"source must survive")
                self.assertFalse((root / "d.zip").exists())
            finally:
                release.set()
                process.join(10)
                if process.is_alive():
                    process.terminate()
                    process.join(5)
                self.assertEqual(process.exitcode, 0)


if __name__ == "__main__":
    multiprocessing.freeze_support()
    unittest.main()
