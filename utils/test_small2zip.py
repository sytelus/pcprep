#!/usr/bin/env python3
"""Unit tests for small2zip.

Run with::

    python -m pytest utils/test_small2zip.py -v      # if pytest is installed
    python utils/test_small2zip.py                   # stdlib unittest fallback

Testing philosophy
------------------
This tool deletes user data, so the tests are weighted toward the *safety
invariant* rather than toward feature coverage:

    A file is deleted from disk ONLY AFTER a readable archive on disk is
    proven to contain that exact file's bytes.

Every failure mode that could violate that invariant gets an explicit test:

* verification failure, cancellation, undeletable files, unexpected exceptions
* files mutated between archive and delete
* same-name/different-content collisions when appending (silent data loss)
* empty directories, which have no representation unless stored explicitly
* symlinks and Windows junctions, which can escape the folder entirely
* ``--keep`` and ``--dry-run``, which promise that nothing is removed

Several of these are marked "Regression:" and name the bug they pin down. A
regression test earns its place only by failing against the bug it describes --
when fixing a data-loss bug, confirm the new test fails with the fix reverted.

The tests drive the real functions against real temporary directories rather
than mocking the filesystem, because the invariant is fundamentally about what
is genuinely on disk. They are fast (~1 s total) despite the real I/O.

Platform note: symlink tests need Windows developer mode, and junction/ADS tests
are Windows-only, so a few cases skip depending on the host. Junctions need no
special privilege, so the out-of-tree deletion guard is always exercised on
Windows.
"""

from __future__ import annotations

import argparse
import contextlib
import io
import os
import sys
import time
import unittest
import zipfile
import zlib
from pathlib import Path
from tempfile import TemporaryDirectory

sys.path.insert(0, str(Path(__file__).resolve().parent))

import small2zip as s  # noqa: E402

from rich.console import Console  # noqa: E402


# --------------------------------------------------------------------------- #
# Helpers
# --------------------------------------------------------------------------- #


def make_args(**overrides) -> argparse.Namespace:
    """Build the argparse.Namespace subset that process_folder reads.

    Kept in sync by hand with the attributes process_folder touches; if you add
    a new flag it reads, add its default here too.
    """
    base = dict(strict=False, verify="full", keep=False, dry_run=False)
    base.update(overrides)
    return argparse.Namespace(**base)


def write_tree(root: Path, files: dict[str, bytes]) -> None:
    """Create *files* (relative path -> contents) under *root*."""
    for rel, content in files.items():
        p = root / rel
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_bytes(content)


@contextlib.contextmanager
def captured_console():
    """Swap the module console for one writing to a buffer.

    Keeps table/prompt output out of the test log and lets assertions inspect
    what the user would have been told.
    """
    buf = io.StringIO()
    original = s.console
    s.console = Console(file=buf, width=200, no_color=True, highlight=False)
    try:
        yield buf
    finally:
        s.console = original


class NullProgress:
    """Stand-in for rich.Progress; process_folder only needs these four methods."""

    def add_task(self, *_a, **_k):
        return 0

    def update(self, *_a, **_k):
        pass

    def advance(self, *_a, **_k):
        pass

    def remove_task(self, *_a, **_k):
        pass


class TempRepo(unittest.TestCase):
    """Base class giving each test an isolated temp directory."""

    def setUp(self) -> None:
        s.cancel_event.clear()  # tests may set it; never leak across cases
        self._tmp = TemporaryDirectory()
        self.root = Path(self._tmp.name)

    def tearDown(self) -> None:
        s.cancel_event.clear()
        self._tmp.cleanup()

    def run_folder(self, folder: Path, **argkw) -> s.FolderResult:
        return s.process_folder(
            folder, self.root, make_args(**argkw), zipfile.ZIP_STORED, None, NullProgress()
        )


# --------------------------------------------------------------------------- #
# Pure helpers
# --------------------------------------------------------------------------- #


class TestHumanSize(unittest.TestCase):
    def test_units_and_boundaries(self) -> None:
        self.assertEqual(s.human_size(0), "0 B")
        self.assertEqual(s.human_size(1023), "1023 B")
        self.assertEqual(s.human_size(1024), "1.0 KiB")
        self.assertEqual(s.human_size(1536), "1.5 KiB")
        self.assertEqual(s.human_size(1024**3), "1.0 GiB")
        self.assertIn("TiB", s.human_size(1024**4))

    def test_every_unit_step_is_exactly_one(self) -> None:
        """Regression: the final unit was labelled without its division.

        1 EiB reported as "1,024.0 EiB" -- off by a factor of 1024.
        """
        units = ("KiB", "MiB", "GiB", "TiB", "PiB", "EiB", "ZiB", "YiB")
        for power, unit in enumerate(units, start=1):
            with self.subTest(unit=unit):
                self.assertEqual(s.human_size(1024**power), f"1.0 {unit}")

    def test_never_reports_a_mantissa_above_1024(self) -> None:
        # Up to the largest unit (YiB); beyond that the mantissa necessarily
        # grows, which is correct rather than a formatting error.
        for power in range(0, 9):
            for mult in (1, 3, 1023):
                got = s.human_size(1024**power * mult)
                mantissa = float(got.split()[0].replace(",", ""))
                self.assertLess(mantissa, 1024.0, got)


def take(iterable, n: int) -> list:
    """First *n* items of an (possibly infinite) iterable."""
    out = []
    for item in iterable:
        out.append(item)
        if len(out) == n:
            break
    return out


class TestArcnameCandidates(unittest.TestCase):
    """The single source of truth for collision naming."""

    def test_first_candidate_is_the_name_itself(self) -> None:
        self.assertEqual(take(s._arcname_candidates("a/b.txt"), 1), ["a/b.txt"])

    def test_suffixes_before_extension(self) -> None:
        self.assertEqual(
            take(s._arcname_candidates("a/b.txt"), 3),
            ["a/b.txt", "a/b__dup1.txt", "a/b__dup2.txt"],
        )

    def test_file_without_extension(self) -> None:
        self.assertEqual(take(s._arcname_candidates("README"), 2), ["README", "README__dup1"])

    def test_dotfile_is_not_split_at_its_leading_dot(self) -> None:
        """splitext treats ".gitignore" as all stem, and so must the dup names."""
        self.assertEqual(
            take(s._arcname_candidates("sub/.gitignore"), 2),
            ["sub/.gitignore", "sub/.gitignore__dup1"],
        )

    def test_candidates_are_unique(self) -> None:
        got = take(s._arcname_candidates("f.txt"), 25)
        self.assertEqual(len(set(got)), len(got))

    def test_dotted_directory_is_not_treated_as_extension(self) -> None:
        """Regression: a dot in a DIRECTORY name must not move the file.

        `rpartition(".")` on the full arcname turned "v1.2/data" into
        "v1__dup1.2/data", silently relocating the entry into a different
        directory on extraction.
        """
        for arc, expected in [
            ("v1.2/data", "v1.2/data__dup1"),
            ("my.dir/file", "my.dir/file__dup1"),
            ("pkg/.bin/tool", "pkg/.bin/tool__dup1"),
            ("x/y.tar.gz", "x/y.tar__dup1.gz"),
        ]:
            with self.subTest(arc=arc):
                got = take(s._arcname_candidates(arc), 2)[1]
                self.assertEqual(got, expected)
                # The directory component must be byte-identical.
                self.assertEqual(got.rpartition("/")[0], arc.rpartition("/")[0])

    def test_directory_arcnames_keep_their_trailing_slash(self) -> None:
        """A dup candidate for a directory must still be a directory member.

        Naive splitting produced "sub/__dup1", which an extractor reads as a
        *file* named __dup1 inside sub/ -- the opposite of a directory entry.
        """
        for arc, expected in [
            ("sub/", "sub__dup1/"),
            ("a/b.d/", "a/b__dup1.d/"),
        ]:
            with self.subTest(arc=arc):
                got = take(s._arcname_candidates(arc), 2)[1]
                self.assertEqual(got, expected)
                self.assertTrue(got.endswith("/"), "lost the directory marker")


class TestFindOrPlace(unittest.TestCase):
    """Placement decisions: write here, or recognise it is already stored."""

    def entry(self, arcname="f.txt", size=4, is_dir=False, attr=0o644 << 16):
        return s.ManifestEntry("src", arcname, size, 0, is_dir=is_dir, external_attr=attr)

    def test_empty_archive_places_at_the_original_name(self) -> None:
        self.assertEqual(s._find_or_place(self.entry(), {}), ("f.txt", None))

    def test_directory_matches_an_existing_directory_member(self) -> None:
        index = {"sub/": (0, 0, 0x41ED0010)}
        self.assertEqual(
            s._find_or_place(self.entry("sub/", 0, is_dir=True), index), ("sub/", 0x41ED0010)
        )

    def test_size_match_alone_does_not_count_as_stored(self) -> None:
        """Same size, different content must not be treated as already archived."""
        with TemporaryDirectory() as tmp:
            src = Path(tmp) / "f.txt"
            src.write_bytes(b"NEW!")
            entry = s.ManifestEntry(str(src), "f.txt", 4, 0)
            index = {"f.txt": (4, zlib.crc32(b"old!"), 0)}
            arcname, stored = s._find_or_place(entry, index)
            self.assertIsNone(stored, "same-size different-content judged as archived")
            self.assertEqual(arcname, "f__dup1.txt")

    def test_recognises_content_already_stored_under_a_dup_name(self) -> None:
        """Regression: the archive grew by one copy on every re-run.

        Only the exact arcname was checked, so a file previously stored as
        f__dup1.txt was never recognised again and a byte-identical f__dup2.txt,
        f__dup3.txt, ... was appended each run.
        """
        with TemporaryDirectory() as tmp:
            src = Path(tmp) / "f.txt"
            src.write_bytes(b"current")
            entry = s.ManifestEntry(str(src), "f.txt", 7, 0, external_attr=0o644 << 16)
            index = {
                "f.txt": (3, zlib.crc32(b"old"), 0),
                "f__dup1.txt": (7, zlib.crc32(b"current"), 0o600 << 16),
            }
            self.assertEqual(s._find_or_place(entry, index), ("f__dup1.txt", 0o600 << 16))


# --------------------------------------------------------------------------- #
# Scanning
# --------------------------------------------------------------------------- #


class TestScanFolder(TempRepo):
    def test_counts_recursively(self) -> None:
        write_tree(self.root, {"d/a.txt": b"12345", "d/sub/b.txt": b"678", "d/sub/deep/c": b"9"})
        st = s.scan_folder(self.root / "d")
        self.assertEqual(st.file_count, 3)
        self.assertEqual(st.total_bytes, 9)
        self.assertEqual(st.dir_count, 2)
        self.assertAlmostEqual(st.avg_bytes, 3.0)

    def test_empty_folder(self) -> None:
        (self.root / "e").mkdir()
        st = s.scan_folder(self.root / "e")
        self.assertEqual((st.file_count, st.total_bytes, st.avg_bytes), (0, 0, 0.0))

    def test_hidden_dirs_excluded_by_default(self) -> None:
        (self.root / ".hidden").mkdir()
        (self.root / "shown").mkdir()
        self.assertEqual([p.name for p in s.iter_top_level_dirs(self.root, False)], ["shown"])
        self.assertEqual(
            sorted(p.name for p in s.iter_top_level_dirs(self.root, True)), [".hidden", "shown"]
        )

    def test_files_at_top_level_are_not_listed_as_dirs(self) -> None:
        write_tree(self.root, {"loose.txt": b"x"})
        (self.root / "d").mkdir()
        self.assertEqual([p.name for p in s.iter_top_level_dirs(self.root, False)], ["d"])


# --------------------------------------------------------------------------- #
# Verification -- the gate that protects the invariant
# --------------------------------------------------------------------------- #


class TestVerifyArchive(TempRepo):
    #: What ZipFile.writestr stamps on a member created from a bare name. The
    #: manifest must agree with the archive or verification (rightly) reports an
    #: attribute mismatch; test_fixture_attr_matches_zipfile guards the constant.
    ATTR = 0o600 << 16

    def _archive(self, members: dict[str, bytes]) -> Path:
        z = self.root / "a.zip"
        with zipfile.ZipFile(z, "w") as zf:
            for name, data in members.items():
                zf.writestr(name, data)
        return z

    def _entry(self, arcname: str, size: int, **kw) -> s.ManifestEntry:
        kw.setdefault("external_attr", self.ATTR)
        return s.ManifestEntry("src", arcname, size, 0, **kw)

    def test_fixture_attr_matches_zipfile(self) -> None:
        """If zipfile changes its writestr default, these fixtures must follow."""
        z = self._archive({"a.txt": b"hello"})
        with zipfile.ZipFile(z) as zf:
            self.assertEqual(zf.getinfo("a.txt").external_attr, self.ATTR)

    def test_clean_archive_reports_no_problems(self) -> None:
        z = self._archive({"a.txt": b"hello"})
        m = [self._entry("a.txt", 5)]
        self.assertEqual(s._verify_archive(z, m, True, NullProgress(), 0), [])

    def test_detects_missing_member(self) -> None:
        z = self._archive({"a.txt": b"hello"})
        m = [self._entry("gone.txt", 1)]
        problems = s._verify_archive(z, m, True, NullProgress(), 0)
        self.assertTrue(any("missing" in p for p in problems), problems)

    def test_detects_size_mismatch(self) -> None:
        z = self._archive({"a.txt": b"hello"})
        m = [self._entry("a.txt", 999)]
        problems = s._verify_archive(z, m, True, NullProgress(), 0)
        self.assertTrue(any("size mismatch" in p for p in problems), problems)

    def test_full_verify_detects_crc_corruption(self) -> None:
        """The check that actually proves the bytes are readable."""
        z = self._archive({"a.txt": b"hello"})
        raw = z.read_bytes().replace(b"hello", b"HELLO")  # same length, bad CRC
        corrupt = self.root / "corrupt.zip"
        corrupt.write_bytes(raw)
        m = [self._entry("a.txt", 5)]
        problems = s._verify_archive(corrupt, m, True, NullProgress(), 0)
        self.assertTrue(any("unreadable" in p or "CRC" in p for p in problems), problems)

    def test_fast_verify_does_not_detect_corruption(self) -> None:
        """Documents the known limitation of --verify fast, so it stays intentional."""
        z = self._archive({"a.txt": b"hello"})
        raw = z.read_bytes().replace(b"hello", b"HELLO")
        corrupt = self.root / "corrupt.zip"
        corrupt.write_bytes(raw)
        m = [self._entry("a.txt", 5)]
        self.assertEqual(s._verify_archive(corrupt, m, False, NullProgress(), 0), [])

    def test_unopenable_archive_is_a_problem_not_an_exception(self) -> None:
        bad = self.root / "notazip.zip"
        bad.write_bytes(b"this is not a zip file")
        problems = s._verify_archive(bad, [self._entry("a", 1)], True, NullProgress(), 0)
        self.assertTrue(problems)


# --------------------------------------------------------------------------- #
# End-to-end: archive -> verify -> delete
# --------------------------------------------------------------------------- #


class TestProcessFolderHappyPath(TempRepo):
    def test_archives_then_deletes(self) -> None:
        write_tree(self.root, {"d/a.txt": b"aaa", "d/sub/b.txt": b"bb"})
        res = self.run_folder(self.root / "d")

        self.assertEqual(res.status, "ok", res.message)
        self.assertEqual(res.archived_files, 2)
        self.assertEqual(res.deleted_files, 2)
        self.assertFalse((self.root / "d").exists(), "source folder must be gone")

        with zipfile.ZipFile(self.root / "d.zip") as zf:
            self.assertIsNone(zf.testzip())
            self.assertEqual(sorted(zf.namelist()), ["a.txt", "sub/", "sub/b.txt"])
            self.assertEqual(zf.read("sub/b.txt"), b"bb")

    def test_no_partial_file_left_behind(self) -> None:
        write_tree(self.root, {"d/a.txt": b"x"})
        self.run_folder(self.root / "d")
        self.assertEqual([p.name for p in self.root.glob("*.partial")], [])

    def test_empty_folder_removed_without_archive(self) -> None:
        (self.root / "empty").mkdir()
        res = self.run_folder(self.root / "empty")
        self.assertEqual(res.status, "ok")
        self.assertFalse((self.root / "empty").exists())
        self.assertFalse((self.root / "empty.zip").exists())

    def test_nested_empty_dirs_are_pruned(self) -> None:
        (self.root / "d" / "a" / "b").mkdir(parents=True)
        write_tree(self.root, {"d/a/f.txt": b"x"})
        res = self.run_folder(self.root / "d")
        self.assertEqual(res.status, "ok", res.message)
        self.assertFalse((self.root / "d").exists())

    def test_keep_flag_archives_but_preserves_source(self) -> None:
        write_tree(self.root, {"d/a.txt": b"x"})
        res = self.run_folder(self.root / "d", keep=True)
        self.assertEqual(res.status, "ok")
        self.assertEqual(res.deleted_files, 0)
        self.assertTrue((self.root / "d" / "a.txt").exists())
        self.assertTrue((self.root / "d.zip").exists())

    def test_keep_does_not_delete_an_empty_folder(self) -> None:
        """Regression: --keep promises nothing is deleted.

        The empty-folder shortcut ran ahead of the --keep check, so a folder
        that happened to be empty was removed anyway.
        """
        (self.root / "empty").mkdir()
        res = self.run_folder(self.root / "empty", keep=True)
        self.assertEqual(res.status, "ok", res.message)
        self.assertTrue((self.root / "empty").exists(), "--keep deleted a folder")

    def test_keep_does_not_delete_nested_empty_dirs(self) -> None:
        (self.root / "d" / "sub").mkdir(parents=True)
        res = self.run_folder(self.root / "d", keep=True)
        self.assertEqual(res.status, "ok", res.message)
        self.assertTrue((self.root / "d" / "sub").exists())

    def test_dry_run_writes_and_deletes_nothing(self) -> None:
        write_tree(self.root, {"d/a.txt": b"x"})
        res = self.run_folder(self.root / "d", dry_run=True)
        self.assertEqual(res.status, "dry-run")
        self.assertTrue((self.root / "d" / "a.txt").exists())
        self.assertFalse((self.root / "d.zip").exists())

    def test_dry_run_does_not_remove_empty_folder(self) -> None:
        """Regression: the empty-folder branch once ran ahead of the dry-run gate."""
        (self.root / "empty").mkdir()
        res = self.run_folder(self.root / "empty", dry_run=True)
        self.assertEqual(res.status, "dry-run")
        self.assertTrue((self.root / "empty").exists())


class TestAppendToExistingArchive(TempRepo):
    def test_adds_new_file_and_skips_identical_one(self) -> None:
        write_tree(self.root, {"d/keep.txt": b"same"})
        self.run_folder(self.root / "d")

        # Recreate with the identical file plus a new one.
        write_tree(self.root, {"d/keep.txt": b"same", "d/new.txt": b"new"})
        res = self.run_folder(self.root / "d")

        self.assertEqual(res.status, "ok", res.message)
        with zipfile.ZipFile(self.root / "d.zip") as zf:
            self.assertEqual(sorted(zf.namelist()), ["keep.txt", "new.txt"])

    def test_same_name_different_size_is_preserved_under_new_name(self) -> None:
        """Neither copy may be lost -- that is the whole point of the rename."""
        write_tree(self.root, {"d/f.txt": b"short"})
        self.run_folder(self.root / "d")
        write_tree(self.root, {"d/f.txt": b"a much longer body"})
        res = self.run_folder(self.root / "d")

        self.assertEqual(res.status, "ok", res.message)
        with zipfile.ZipFile(self.root / "d.zip") as zf:
            self.assertEqual(sorted(zf.namelist()), ["f.txt", "f__dup1.txt"])
            self.assertEqual(zf.read("f.txt"), b"short")
            self.assertEqual(zf.read("f__dup1.txt"), b"a much longer body")

    def test_same_size_different_content_is_not_mistaken_for_archived(self) -> None:
        """Regression, data loss: the skip test was size-only.

        A file edited in place to the *same length* matched the stored member on
        name+size, was declared "already archived", and the source was deleted --
        while the archive still held the stale bytes. The skip now also compares
        CRC32, so the edited copy is stored alongside the original.
        """
        write_tree(self.root, {"d/a.txt": b"hello"})
        self.run_folder(self.root / "d")

        (self.root / "d").mkdir(exist_ok=True)
        (self.root / "d" / "a.txt").write_bytes(b"world")  # same 5 bytes, new content
        res = self.run_folder(self.root / "d")

        self.assertEqual(res.status, "ok", res.message)
        with zipfile.ZipFile(self.root / "d.zip") as zf:
            stored = {name: zf.read(name) for name in zf.namelist()}
        self.assertIn(b"hello", stored.values(), "original copy lost")
        self.assertIn(b"world", stored.values(), "DATA LOSS: new content never archived")

    def test_identical_content_is_skipped_without_duplicating(self) -> None:
        """The CRC check must not turn every re-run into a duplicate member."""
        write_tree(self.root, {"d/a.txt": b"unchanged"})
        self.run_folder(self.root / "d")
        write_tree(self.root, {"d/a.txt": b"unchanged"})
        res = self.run_folder(self.root / "d")

        self.assertEqual(res.status, "ok", res.message)
        with zipfile.ZipFile(self.root / "d.zip") as zf:
            self.assertEqual(zf.namelist(), ["a.txt"], "identical file re-added")

    def test_repeated_runs_do_not_grow_the_archive(self) -> None:
        """Regression: every re-run appended another byte-identical copy.

        Run 2 correctly stores the edited file as f__dup1.txt. Run 3 (same
        content again) used to add f__dup2.txt, run 4 f__dup3.txt, and so on --
        the archive grew without bound while nothing had changed.
        """
        write_tree(self.root, {"d/f.txt": b"version-one"})
        self.run_folder(self.root / "d")

        for _ in range(3):
            write_tree(self.root, {"d/f.txt": b"version-two-is-longer"})
            res = self.run_folder(self.root / "d")
            self.assertEqual(res.status, "ok", res.message)

        with zipfile.ZipFile(self.root / "d.zip") as zf:
            names = zf.namelist()
            bodies = [zf.read(n) for n in names]
        self.assertEqual(sorted(names), ["f.txt", "f__dup1.txt"], names)
        self.assertEqual(len(bodies), len(set(bodies)), "byte-identical duplicates stored")
        self.assertIn(b"version-one", bodies)
        self.assertIn(b"version-two-is-longer", bodies)

    def test_strict_refuses_when_archive_exists(self) -> None:
        write_tree(self.root, {"d/a.txt": b"x"})
        self.run_folder(self.root / "d")
        write_tree(self.root, {"d/b.txt": b"y"})
        res = self.run_folder(self.root / "d", strict=True)

        self.assertEqual(res.status, "skipped")
        self.assertTrue((self.root / "d" / "b.txt").exists(), "source must survive a skip")

    def test_existing_archive_survives_a_failed_append(self) -> None:
        """The pre-existing archive is copied, never mutated in place."""
        write_tree(self.root, {"d/a.txt": b"original"})
        self.run_folder(self.root / "d")
        before = (self.root / "d.zip").read_bytes()

        write_tree(self.root, {"d/b.txt": b"second"})
        s.cancel_event.set()  # force the append to abort mid-flight
        res = self.run_folder(self.root / "d")
        s.cancel_event.clear()

        self.assertEqual(res.status, "cancelled")
        self.assertEqual((self.root / "d.zip").read_bytes(), before, "archive was mutated")


# --------------------------------------------------------------------------- #
# Safety: every path that must NOT delete data
# --------------------------------------------------------------------------- #


class TestSafetyInvariant(TempRepo):
    def test_verification_failure_keeps_all_sources(self) -> None:
        """If verify reports problems, nothing may be deleted."""
        write_tree(self.root, {"d/a.txt": b"aaa", "d/b.txt": b"bbb"})
        original = s._verify_archive
        s._verify_archive = lambda *a, **k: ["injected failure"]
        try:
            res = self.run_folder(self.root / "d")
        finally:
            s._verify_archive = original

        self.assertEqual(res.status, "failed")
        self.assertEqual(res.deleted_files, 0)
        self.assertTrue((self.root / "d" / "a.txt").exists())
        self.assertTrue((self.root / "d" / "b.txt").exists())
        self.assertFalse((self.root / "d.zip").exists(), "unverified archive must not publish")
        self.assertEqual([p.name for p in self.root.glob("*.partial")], [])

    def test_cancellation_deletes_nothing_and_leaves_no_partial(self) -> None:
        write_tree(self.root, {f"d/f{i}.txt": b"x" * 50 for i in range(50)})
        s.cancel_event.set()
        res = self.run_folder(self.root / "d")
        s.cancel_event.clear()

        self.assertEqual(res.status, "cancelled")
        self.assertEqual(res.deleted_files, 0)
        self.assertEqual(len(list((self.root / "d").iterdir())), 50, "all sources must survive")
        self.assertEqual([p.name for p in self.root.glob("*.partial")], [])
        self.assertFalse((self.root / "d.zip").exists())

    def test_file_modified_after_archiving_is_kept(self) -> None:
        """A file whose bytes changed post-archive is no longer represented."""
        write_tree(self.root, {"d/stable.txt": b"stable", "d/mutated.txt": b"before"})
        real_verify = s._verify_archive

        def verify_then_mutate(*a, **k):
            problems = real_verify(*a, **k)
            # Simulate another process rewriting the file after verification.
            p = self.root / "d" / "mutated.txt"
            p.write_bytes(b"a completely different and longer body")
            return problems

        s._verify_archive = verify_then_mutate
        try:
            res = self.run_folder(self.root / "d")
        finally:
            s._verify_archive = real_verify

        self.assertEqual(res.status, "failed", "a kept file must surface as a failure")
        self.assertTrue((self.root / "d" / "mutated.txt").exists(), "changed file must survive")
        self.assertEqual((self.root / "d" / "mutated.txt").read_bytes(), b"a completely different and longer body")
        self.assertTrue(any("modified after archiving" in u for u in res.undeleted), res.undeleted)

    def test_undeletable_file_is_reported_and_still_archived(self) -> None:
        """The worst acceptable outcome: file on disk AND in the archive."""
        write_tree(self.root, {"d/held.txt": b"important", "d/free.txt": b"other"})
        held = self.root / "d" / "held.txt"

        real_remove = s._force_remove

        def refuse_one(path: str) -> None:
            if os.path.basename(path) == "held.txt":
                raise PermissionError(13, "in use by another process")
            real_remove(path)

        s._force_remove = refuse_one
        try:
            res = self.run_folder(self.root / "d")
        finally:
            s._force_remove = real_remove

        self.assertEqual(res.status, "failed")
        self.assertTrue(held.exists(), "undeletable file must remain on disk")
        with zipfile.ZipFile(self.root / "d.zip") as zf:
            self.assertIn("held.txt", zf.namelist())
            self.assertEqual(zf.read("held.txt"), b"important")
        self.assertTrue(any("held.txt" in u for u in res.undeleted), res.undeleted)

    @unittest.skipUnless(hasattr(os, "symlink"), "platform lacks symlinks")
    def test_symlink_blocks_deletion_of_its_folder(self) -> None:
        write_tree(self.root, {"d/real.txt": b"data"})
        try:
            os.symlink(self.root / "d" / "real.txt", self.root / "d" / "link.txt")
        except (OSError, NotImplementedError) as exc:  # Windows without dev mode
            self.skipTest(f"cannot create symlink: {exc}")

        res = self.run_folder(self.root / "d")
        self.assertEqual(res.status, "skipped")
        self.assertTrue((self.root / "d").exists(), "folder with a symlink must survive")
        self.assertTrue((self.root / "d.zip").exists(), "archive should still be written")

    def test_unreadable_source_archives_the_rest_and_keeps_the_folder(self) -> None:
        """A file lost between enumeration and write must not sink the folder.

        Previously the OSError escaped to the catch-all handler, so a single
        vanished or locked file discarded the archive for the whole folder --
        potentially a million files of work. It is now a blocker: everything
        readable is archived, and the folder survives because something did not
        make it in.
        """
        write_tree(self.root, {f"d/f{i}.txt": b"body" for i in range(4)})
        real_collect = s._collect_files

        def collect_plus_phantom(folder, result):
            entries, blockers = real_collect(folder, result)
            # A path that no longer exists by the time the writer reaches it.
            entries.append(s.ManifestEntry(str(folder / "vanished.txt"), "vanished.txt", 9, 0))
            return entries, blockers

        s._collect_files = collect_plus_phantom
        try:
            res = self.run_folder(self.root / "d")
        finally:
            s._collect_files = real_collect

        self.assertEqual(res.status, "skipped", res.message)
        self.assertTrue((self.root / "d").exists(), "folder must survive an archive failure")
        with zipfile.ZipFile(self.root / "d.zip") as zf:
            self.assertEqual(sorted(zf.namelist()), [f"f{i}.txt" for i in range(4)])
            self.assertIsNone(zf.testzip())

    def test_blockers_only_folder_publishes_no_archive(self) -> None:
        """An all-unarchivable folder must not leave an empty zip behind.

        An empty `<folder>.zip` beside a folder that was deliberately kept is
        clutter that also reads as "this folder was archived" when nothing was.
        """
        (self.root / "d").mkdir()
        real_collect = s._collect_files
        s._collect_files = lambda folder, result: ([], ["not a regular file: fifo"])
        try:
            res = self.run_folder(self.root / "d")
        finally:
            s._collect_files = real_collect

        self.assertEqual(res.status, "skipped")
        self.assertFalse((self.root / "d.zip").exists(), "empty archive must not be published")
        self.assertTrue((self.root / "d").exists())

    def test_all_writes_failing_publishes_no_archive(self) -> None:
        """Regression: write-time failures could still publish an empty zip.

        The blockers-only guard covered collect-time failures, but when every
        entry failed at WRITE time (all files locked or vanished) the empty
        manifest sailed through verification and the empty archive was
        published -- which under --strict then blocked the folder forever.
        """
        (self.root / "d").mkdir()
        real_collect = s._collect_files

        def phantoms_only(folder, result):
            real_collect(folder, result)  # keep the walk honest
            return (
                [s.ManifestEntry(str(folder / f"gone{i}.txt"), f"gone{i}.txt", 5, 0)
                 for i in range(2)],
                [],
            )

        s._collect_files = phantoms_only
        try:
            res = self.run_folder(self.root / "d")
        finally:
            s._collect_files = real_collect

        self.assertEqual(res.status, "skipped", res.message)
        self.assertTrue((self.root / "d").exists(), "folder must survive")
        self.assertFalse((self.root / "d.zip").exists(), "empty archive must not publish")
        self.assertEqual([p.name for p in self.root.glob("*.partial")], [])

    def test_unexpected_exception_does_not_delete_or_crash(self) -> None:
        write_tree(self.root, {"d/a.txt": b"x"})
        original = s._archive_folder
        s._archive_folder = lambda *a, **k: (_ for _ in ()).throw(RuntimeError("boom"))
        try:
            res = self.run_folder(self.root / "d")
        finally:
            s._archive_folder = original

        self.assertEqual(res.status, "failed")
        self.assertIn("boom", res.message)
        self.assertTrue((self.root / "d" / "a.txt").exists())


# --------------------------------------------------------------------------- #
# Attribute and structure retention
# --------------------------------------------------------------------------- #

WINDOWS = sys.platform == "win32"


class TestAttributeRetention(TempRepo):
    """The source is deleted, so anything not stored here is gone for good."""

    def test_empty_directories_are_archived_not_destroyed(self) -> None:
        """Regression, data loss: empty dirs had no archive representation.

        They were walked past by the collector, absent from the zip, and then
        removed by the bottom-up prune -- structure destroyed with no copy.
        """
        (self.root / "d" / "empty").mkdir(parents=True)
        (self.root / "d" / "nested" / "deep").mkdir(parents=True)
        write_tree(self.root, {"d/nested/f.txt": b"f"})

        res = self.run_folder(self.root / "d")
        self.assertEqual(res.status, "ok", res.message)
        self.assertFalse((self.root / "d").exists())

        with zipfile.ZipFile(self.root / "d.zip") as zf:
            self.assertEqual(
                sorted(zf.namelist()),
                ["empty/", "nested/", "nested/deep/", "nested/f.txt"],
            )
            out = self.root / "restored"
            zf.extractall(out)

        self.assertTrue((out / "empty").is_dir(), "empty dir lost on round-trip")
        self.assertTrue((out / "nested" / "deep").is_dir(), "nested empty dir lost")
        self.assertEqual((out / "nested" / "f.txt").read_bytes(), b"f")

    def test_directory_members_are_marked_as_directories(self) -> None:
        (self.root / "d" / "sub").mkdir(parents=True)
        write_tree(self.root, {"d/sub/f.txt": b"x"})
        self.run_folder(self.root / "d")
        with zipfile.ZipFile(self.root / "d.zip") as zf:
            info = zf.getinfo("sub/")
            self.assertTrue(info.is_dir())
            self.assertEqual(info.file_size, 0)
            self.assertTrue(info.external_attr & 0x10, "DOS directory bit not set")
            self.assertTrue(info.external_attr >> 16 & 0o40000, "unix dir bit not set")

    def test_readonly_attribute_is_recorded(self) -> None:
        write_tree(self.root, {"d/ro.txt": b"locked"})
        os.chmod(self.root / "d" / "ro.txt", 0o444)
        self.run_folder(self.root / "d")

        with zipfile.ZipFile(self.root / "d.zip") as zf:
            attr = zf.getinfo("ro.txt").external_attr
        if WINDOWS:
            self.assertTrue(attr & 0x01, "DOS read-only bit not recorded")
        self.assertFalse((attr >> 16) & 0o200, "unix owner-write bit should be clear")

    @unittest.skipUnless(WINDOWS, "DOS hidden/system bits are Windows-only")
    def test_hidden_and_system_attributes_are_recorded(self) -> None:
        """These have no Unix mode equivalent, so they were dropped entirely."""
        import ctypes

        write_tree(self.root, {"d/hidden.txt": b"h", "d/system.txt": b"s"})
        set_attr = ctypes.windll.kernel32.SetFileAttributesW
        self.assertTrue(set_attr(str(self.root / "d" / "hidden.txt"), 0x02))
        self.assertTrue(set_attr(str(self.root / "d" / "system.txt"), 0x04))

        res = self.run_folder(self.root / "d")
        self.assertEqual(res.status, "ok", res.message)
        with zipfile.ZipFile(self.root / "d.zip") as zf:
            self.assertTrue(zf.getinfo("hidden.txt").external_attr & 0x02, "HIDDEN lost")
            self.assertTrue(zf.getinfo("system.txt").external_attr & 0x04, "SYSTEM lost")

    @unittest.skipIf(WINDOWS, "Windows has no meaningful unix mode bits")
    def test_unix_mode_is_preserved(self) -> None:
        write_tree(self.root, {"d/script.sh": b"#!/bin/sh\n", "d/plain.txt": b"x"})
        os.chmod(self.root / "d" / "script.sh", 0o750)
        os.chmod(self.root / "d" / "plain.txt", 0o640)
        self.run_folder(self.root / "d")

        with zipfile.ZipFile(self.root / "d.zip") as zf:
            self.assertEqual((zf.getinfo("script.sh").external_attr >> 16) & 0o777, 0o750)
            self.assertEqual((zf.getinfo("plain.txt").external_attr >> 16) & 0o777, 0o640)

    def test_directories_are_never_unlinked(self) -> None:
        """Dir entries must reach the prune, not os.remove, which would fail."""
        (self.root / "d" / "sub").mkdir(parents=True)
        write_tree(self.root, {"d/sub/f.txt": b"x"})
        seen: list[str] = []
        real_remove = s._force_remove

        def spy(path: str) -> None:
            seen.append(path)
            real_remove(path)

        s._force_remove = spy
        try:
            res = self.run_folder(self.root / "d")
        finally:
            s._force_remove = real_remove

        self.assertEqual(res.status, "ok", res.message)
        self.assertEqual(res.undeleted, [])
        self.assertTrue(all(not os.path.isdir(p) for p in seen))
        self.assertEqual(len(seen), 1, seen)

    def test_counts_report_files_and_dirs_separately(self) -> None:
        (self.root / "d" / "a").mkdir(parents=True)
        write_tree(self.root, {"d/1.txt": b"x", "d/a/2.txt": b"yy"})
        res = self.run_folder(self.root / "d")
        self.assertEqual(res.archived_files, 2)
        self.assertEqual(res.archived_dirs, 1)
        self.assertEqual(res.archived_bytes, 3, "dir members must not add bytes")


class TestTimestamps(TempRepo):
    #: Well before zip's 1980 floor, and safely representable on every platform.
    ANCIENT = 86400.0  # 1970-01-02

    def test_pre_1980_file_is_archived_not_blocked_forever(self) -> None:
        """Regression: such a file could never be archived, so its folder could
        never be reclaimed -- a permanent stuck state, not a transient failure.

        zip refuses to write a header dated before 1980. The timestamp is
        clamped instead; losing an approximate mtime beats an unprocessable
        folder.
        """
        write_tree(self.root, {"d/ancient.txt": b"old", "d/normal.txt": b"new"})
        os.utime(self.root / "d" / "ancient.txt", (self.ANCIENT, self.ANCIENT))

        res = self.run_folder(self.root / "d")

        self.assertEqual(res.status, "ok", res.message)
        self.assertFalse((self.root / "d").exists(), "folder must be reclaimable")
        with zipfile.ZipFile(self.root / "d.zip") as zf:
            self.assertEqual(sorted(zf.namelist()), ["ancient.txt", "normal.txt"])
            self.assertEqual(zf.read("ancient.txt"), b"old")
            self.assertEqual(zf.getinfo("ancient.txt").date_time, s._DOS_EPOCH)

    def test_pre_1980_directory_is_clamped(self) -> None:
        (self.root / "d" / "olddir").mkdir(parents=True)
        write_tree(self.root, {"d/f.txt": b"x"})
        os.utime(self.root / "d" / "olddir", (self.ANCIENT, self.ANCIENT))

        res = self.run_folder(self.root / "d")
        self.assertEqual(res.status, "ok", res.message)
        with zipfile.ZipFile(self.root / "d.zip") as zf:
            self.assertEqual(zf.getinfo("olddir/").date_time, s._DOS_EPOCH)

    def test_normal_timestamps_are_preserved_to_dos_resolution(self) -> None:
        write_tree(self.root, {"d/f.txt": b"x"})
        when = time.mktime((2021, 6, 15, 12, 30, 20, 0, 0, -1))
        os.utime(self.root / "d" / "f.txt", (when, when))
        self.run_folder(self.root / "d")
        with zipfile.ZipFile(self.root / "d.zip") as zf:
            self.assertEqual(zf.getinfo("f.txt").date_time, (2021, 6, 15, 12, 30, 20))

    def test_nonsense_mtime_falls_back_to_the_dos_epoch(self) -> None:
        self.assertEqual(s._dos_date_time(-(10**26)), s._DOS_EPOCH)
        self.assertEqual(s._dos_date_time(10**30), s._DOS_EPOCH)


class TestProcessFolderNeverRaises(TempRepo):
    """run_delete calls fut.result(); an escape aborts the entire run."""

    def test_progress_failure_is_contained(self) -> None:
        """Regression: add_task ran before the try block, so it escaped."""
        write_tree(self.root, {"d/a.txt": b"x"})

        class ExplodingProgress(NullProgress):
            def add_task(self, *_a, **_k):
                raise RuntimeError("progress exploded")

        res = s.process_folder(
            self.root / "d", self.root, make_args(), zipfile.ZIP_STORED, None,
            ExplodingProgress(),
        )
        self.assertEqual(res.status, "failed")
        self.assertIn("progress exploded", res.message)
        self.assertTrue((self.root / "d" / "a.txt").exists(), "nothing may be deleted")

    def test_teardown_failure_is_contained(self) -> None:
        class BadTeardown(NullProgress):
            def remove_task(self, *_a, **_k):
                raise RuntimeError("teardown exploded")

        write_tree(self.root, {"d/a.txt": b"x"})
        res = s.process_folder(
            self.root / "d", self.root, make_args(), zipfile.ZIP_STORED, None, BadTeardown()
        )
        self.assertEqual(res.status, "ok", res.message)

    def test_run_delete_survives_a_folder_that_raises(self) -> None:
        """Losing one folder's report must not discard the whole run."""
        write_tree(self.root, {"a/1.txt": b"x", "b/2.txt": b"y"})
        real = s.process_folder

        def explode_on_a(folder, *args, **kw):
            if folder.name == "a":
                raise RuntimeError("worker exploded")
            return real(folder, *args, **kw)

        s.process_folder = explode_on_a
        try:
            with captured_console():
                results = s.run_delete(
                    self.root,
                    [self.root / "a", self.root / "b"],
                    argparse.Namespace(
                        strict=False, verify="full", keep=False, dry_run=False,
                        compress="store", level=None, workers=2,
                    ),
                )
        finally:
            s.process_folder = real

        by_name = {r.name: r for r in results}
        self.assertEqual(set(by_name), {"a", "b"}, "a failing folder lost the whole run")
        self.assertEqual(by_name["a"].status, "failed")
        self.assertEqual(by_name["b"].status, "ok", by_name["b"].message)


class TestVerifyAttributes(TempRepo):
    def test_attribute_tampering_blocks_deletion(self) -> None:
        """We promise attribute retention, so verification must enforce it."""
        write_tree(self.root, {"d/a.txt": b"body"})
        real_verify = s._verify_archive

        def verify_with_tampered_manifest(archive, manifest, full, progress, task_id):
            bad = [replace_attr(e) for e in manifest]
            return real_verify(archive, bad, full, progress, task_id)

        def replace_attr(e):
            from dataclasses import replace
            return replace(e, external_attr=e.external_attr ^ 0xFF)

        s._verify_archive = verify_with_tampered_manifest
        try:
            res = self.run_folder(self.root / "d")
        finally:
            s._verify_archive = real_verify

        self.assertEqual(res.status, "failed")
        self.assertTrue((self.root / "d" / "a.txt").exists(), "source must survive")
        self.assertFalse((self.root / "d.zip").exists())

    def test_content_corruption_is_reported_even_when_attrs_also_differ(self) -> None:
        """An attribute mismatch must never short-circuit the CRC check."""
        z = self.root / "a.zip"
        with zipfile.ZipFile(z, "w") as zf:
            zf.writestr("a.txt", b"hello")
        corrupt = self.root / "corrupt.zip"
        corrupt.write_bytes(z.read_bytes().replace(b"hello", b"HELLO"))

        # Manifest disagrees on BOTH content and attributes.
        m = [s.ManifestEntry("src", "a.txt", 5, 0, external_attr=0)]
        problems = s._verify_archive(corrupt, m, True, NullProgress(), 0)
        self.assertTrue(
            any("unreadable" in p for p in problems),
            f"CRC failure masked by attribute check: {problems}",
        )


class TestLegacyArchiveCompatibility(TempRepo):
    def test_appending_to_an_attributeless_archive_still_works(self) -> None:
        """Archives from before attribute support must not become undeletable.

        Their members carry whatever attrs the old writer used. Verification
        compares the manifest against the archive, so the manifest adopts the
        stored value rather than the source's current one -- otherwise every
        pre-existing archive would fail verification forever.
        """
        write_tree(self.root, {"d/old.txt": b"old", "d/new.txt": b"new"})
        legacy = self.root / "d.zip"
        with zipfile.ZipFile(legacy, "w") as zf:
            zf.writestr("old.txt", b"old")  # no dir entries, foreign attrs

        res = self.run_folder(self.root / "d")

        self.assertEqual(res.status, "ok", res.message)
        self.assertFalse((self.root / "d").exists(), "folder should be reclaimed")
        with zipfile.ZipFile(legacy) as zf:
            self.assertEqual(sorted(zf.namelist()), ["new.txt", "old.txt"])
            self.assertEqual(zf.read("old.txt"), b"old")
            self.assertEqual(zf.read("new.txt"), b"new")


def make_junction(link: Path, target: Path) -> bool:
    """Create a Windows directory junction. Unlike symlinks, needs no privilege."""
    if not WINDOWS:
        return False
    import subprocess

    subprocess.run(
        ["cmd", "/c", "mklink", "/J", str(link), str(target)],
        capture_output=True, text=True,
    )
    return link.exists()


class TestLinkLikePaths(TempRepo):
    """Nothing that can point outside the folder may be followed."""

    @unittest.skipUnless(WINDOWS, "junctions are Windows-only")
    def test_junction_is_never_followed_or_deleted_through(self) -> None:
        """Regression, out-of-tree data loss.

        `DirEntry.is_symlink()` is False for a junction, so it looked like a
        plain directory: the tool recursed through it, archived files that live
        OUTSIDE the folder, then deleted them from their real location.
        """
        write_tree(self.root, {"d/real.txt": b"mine"})
        outside = self.root / "elsewhere"
        outside.mkdir()
        (outside / "precious.txt").write_bytes(b"NOT YOURS")
        if not make_junction(self.root / "d" / "j", outside):
            self.skipTest("could not create a junction")

        res = self.run_folder(self.root / "d")

        self.assertEqual(res.status, "skipped", res.message)
        self.assertTrue(
            (outside / "precious.txt").exists(), "deleted a file OUTSIDE the target folder"
        )
        self.assertEqual((outside / "precious.txt").read_bytes(), b"NOT YOURS")
        self.assertTrue((self.root / "d").exists(), "folder with a junction must survive")
        with zipfile.ZipFile(self.root / "d.zip") as zf:
            self.assertEqual(zf.namelist(), ["real.txt"])
            self.assertFalse(
                any("precious" in n for n in zf.namelist()), "archived through the junction"
            )

    @unittest.skipUnless(WINDOWS, "junctions are Windows-only")
    def test_top_level_junction_is_not_processed(self) -> None:
        outside = self.root / "elsewhere"
        outside.mkdir()
        (outside / "precious.txt").write_bytes(b"NOT YOURS")
        (self.root / "normal").mkdir()
        if not make_junction(self.root / "j", outside):
            self.skipTest("could not create a junction")

        found = [p.name for p in s.iter_top_level_dirs(self.root, False)]
        self.assertIn("normal", found)
        self.assertNotIn("j", found, "a junction must not be treated as a target folder")

    @unittest.skipUnless(WINDOWS, "junctions are Windows-only")
    def test_junction_does_not_inflate_the_listing(self) -> None:
        write_tree(self.root, {"d/a.txt": b"x"})
        outside = self.root / "elsewhere"
        outside.mkdir()
        write_tree(outside, {f"f{i}.txt": b"y" * 100 for i in range(5)})
        if not make_junction(self.root / "d" / "j", outside):
            self.skipTest("could not create a junction")

        st = s.scan_folder(self.root / "d")
        self.assertEqual(st.file_count, 1, "counted files reached through a junction")
        self.assertEqual(st.symlink_count, 1)


class TestUnpreservableMetadata(TempRepo):
    """Metadata zip cannot hold does NOT block reclaiming the space.

    ACLs, alternate data streams and owner/group are intentionally not preserved
    and intentionally not treated as blockers -- the file's contents are what
    the archive guarantees.
    """

    @unittest.skipUnless(WINDOWS, "alternate data streams are NTFS-only")
    def test_alternate_data_stream_does_not_block_deletion(self) -> None:
        write_tree(self.root, {"d/f.txt": b"main stream"})
        with open(str(self.root / "d" / "f.txt") + ":extra", "w") as fh:
            fh.write("side stream")

        res = self.run_folder(self.root / "d")

        self.assertEqual(res.status, "ok", res.message)
        self.assertFalse((self.root / "d").exists(), "ADS must not prevent reclaiming")
        with zipfile.ZipFile(self.root / "d.zip") as zf:
            self.assertEqual(zf.read("f.txt"), b"main stream")

    @unittest.skipIf(WINDOWS, "POSIX permission semantics")
    def test_unusual_ownership_bits_do_not_block_deletion(self) -> None:
        write_tree(self.root, {"d/setgid.txt": b"data"})
        os.chmod(self.root / "d" / "setgid.txt", 0o2644)  # setgid: not zip-representable
        res = self.run_folder(self.root / "d")
        self.assertEqual(res.status, "ok", res.message)
        self.assertFalse((self.root / "d").exists())


# --------------------------------------------------------------------------- #
# CLI wiring
# --------------------------------------------------------------------------- #


class TestFileCrc32(TempRepo):
    def test_matches_zlib_over_chunk_boundaries(self) -> None:
        for size in (0, 1, s.CHUNK_SIZE - 1, s.CHUNK_SIZE, s.CHUNK_SIZE + 1):
            with self.subTest(size=size):
                p = self.root / f"f{size}.bin"
                data = bytes(i % 251 for i in range(size))
                p.write_bytes(data)
                self.assertEqual(s._file_crc32(str(p)), zlib.crc32(data))

    def test_matches_the_crc_zipfile_stores(self) -> None:
        """The skip check compares against ZipInfo.CRC, so the two must agree."""
        p = self.root / "f.bin"
        p.write_bytes(b"payload" * 500)
        z = self.root / "a.zip"
        with zipfile.ZipFile(z, "w") as zf:
            zf.write(p, "f.bin")
        with zipfile.ZipFile(z) as zf:
            self.assertEqual(zf.getinfo("f.bin").CRC, s._file_crc32(str(p)))


class TestCollectFiles(TempRepo):
    def test_enumerates_regular_files_with_relative_arcnames(self) -> None:
        write_tree(self.root, {"d/a.txt": b"12345", "d/sub/b.txt": b"67"})
        entries, blockers = s._collect_files(self.root / "d", s.FolderResult(name="d"))
        self.assertEqual(blockers, [])
        by_arc = {e.arcname: e for e in entries}
        self.assertEqual(sorted(by_arc), ["a.txt", "sub/", "sub/b.txt"])
        self.assertEqual(by_arc["a.txt"].size, 5)
        self.assertTrue(by_arc["sub/"].is_dir)
        self.assertEqual(by_arc["sub/"].size, 0)

    def test_arcnames_always_use_forward_slashes(self) -> None:
        """Zip requires '/' separators regardless of the host platform."""
        write_tree(self.root, {"d/x/y/z.txt": b"q"})
        entries, _ = s._collect_files(self.root / "d", s.FolderResult(name="d"))
        self.assertEqual([e.arcname for e in entries], ["x/", "x/y/", "x/y/z.txt"])
        self.assertFalse(any("\\" in e.arcname for e in entries))

    def test_directories_precede_their_contents(self) -> None:
        """Extractors expect a directory member before anything inside it."""
        write_tree(self.root, {"d/x/y/z.txt": b"q", "d/a.txt": b"a"})
        entries, _ = s._collect_files(self.root / "d", s.FolderResult(name="d"))
        names = [e.arcname for e in entries]
        for i, name in enumerate(names):
            if "/" in name.rstrip("/"):
                parent = name.rstrip("/").rpartition("/")[0] + "/"
                self.assertLess(names.index(parent), i, f"{parent} must precede {name}")

    def test_unreadable_directory_becomes_a_blocker(self) -> None:
        (self.root / "d").mkdir()
        entries, blockers = s._collect_files(self.root / "d" / "gone", s.FolderResult(name="d"))
        self.assertEqual(entries, [])
        self.assertTrue(blockers, "an unreadable path must block deletion")


class TestRenderSummary(TempRepo):
    def _codes(self, *results: s.FolderResult) -> int:
        with captured_console():
            return s.render_summary(list(results), None)

    def test_all_ok_exits_zero(self) -> None:
        self.assertEqual(self._codes(s.FolderResult(name="a", status="ok")), 0)

    def test_any_failure_exits_one(self) -> None:
        self.assertEqual(
            self._codes(s.FolderResult(name="a", status="ok"),
                        s.FolderResult(name="b", status="failed")), 1)

    def test_cancellation_exits_130(self) -> None:
        self.assertEqual(self._codes(s.FolderResult(name="a", status="cancelled")), 130)

    def test_failure_outranks_cancellation(self) -> None:
        self.assertEqual(
            self._codes(s.FolderResult(name="a", status="cancelled"),
                        s.FolderResult(name="b", status="failed")), 1)

    def test_every_status_has_a_style(self) -> None:
        """render_summary indexes STATUS_STYLE directly; a gap would KeyError."""
        for status in ("ok", "skipped", "failed", "cancelled", "dry-run", "pending"):
            with self.subTest(status=status):
                self.assertIn(status, s.STATUS_STYLE)


class TestLogging(TempRepo):
    def tearDown(self) -> None:
        s.setup_logging(None, False)  # release any file handle before cleanup
        super().tearDown()

    def test_repeated_setup_does_not_stack_handlers(self) -> None:
        """Each call used to add another FileHandler: duplicate lines, leaked fds."""
        path = self.root / "logs" / "run.log"
        for _ in range(3):
            s.setup_logging(path, False)
        kinds = [type(h).__name__ for h in s.log.handlers]
        self.assertEqual(kinds.count("FileHandler"), 1, kinds)

    def test_creates_missing_parent_directories(self) -> None:
        path = self.root / "deep" / "nested" / "run.log"
        s.setup_logging(path, False)
        log_line = "canary-entry"
        s.log.info(log_line)
        for handler in s.log.handlers:
            handler.flush()
        self.assertIn(log_line, path.read_text(encoding="utf-8"))

    def test_unwritable_log_path_exits_cleanly(self) -> None:
        """A bad --log used to escape as a raw traceback."""
        blocker = self.root / "afile"
        blocker.write_bytes(b"not a directory")
        with captured_console() as buf:
            code = s.main(["-l", str(self.root), "--log", str(blocker / "sub" / "x.log")])
        self.assertEqual(code, 2)
        self.assertIn("log file", buf.getvalue())

    def test_no_log_leaves_only_a_null_handler(self) -> None:
        s.setup_logging(None, False)
        self.assertEqual([type(h).__name__ for h in s.log.handlers], ["NullHandler"])

    def test_logs_the_argv_it_was_given_not_the_hosts(self) -> None:
        """Regression: main(argv) logged sys.argv -- the test runner's args --
        so the audit trail for an embedded/programmatic run was wrong."""
        path = self.root / "run.log"
        with captured_console():
            s.main(["-l", str(self.root), "--log", str(path)])
        s.setup_logging(None, False)  # release the file handle before reading
        content = path.read_text(encoding="utf-8")
        self.assertIn(f"'-l', '{str(self.root)}'".replace("\\", "\\\\"), content)


class TestMainEndToEnd(TempRepo):
    def test_delete_mode_archives_and_removes_every_folder(self) -> None:
        write_tree(self.root, {"a/1.txt": b"one", "b/2.txt": b"two", "b/sub/3.txt": b"three"})
        with captured_console():
            code = s.main(["-d", str(self.root), "-y", "--no-log"])

        self.assertEqual(code, 0)
        self.assertFalse((self.root / "a").exists())
        self.assertFalse((self.root / "b").exists())
        with zipfile.ZipFile(self.root / "b.zip") as zf:
            self.assertEqual(sorted(zf.namelist()), ["2.txt", "sub/", "sub/3.txt"])

    def test_dry_run_needs_no_confirmation_and_changes_nothing(self) -> None:
        write_tree(self.root, {"a/1.txt": b"one"})
        with captured_console():
            code = s.main(["-d", str(self.root), "--dry-run", "--no-log"])

        self.assertEqual(code, 0)
        self.assertTrue((self.root / "a" / "1.txt").exists())
        self.assertEqual(list(self.root.glob("*.zip")), [])

    def test_declining_the_prompt_changes_nothing(self) -> None:
        write_tree(self.root, {"a/1.txt": b"one"})
        with captured_console():
            original = s.confirm_destructive
            s.confirm_destructive = lambda *a, **k: False
            try:
                code = s.main(["-d", str(self.root), "--no-log"])
            finally:
                s.confirm_destructive = original

        self.assertEqual(code, 1)
        self.assertTrue((self.root / "a" / "1.txt").exists())
        self.assertEqual(list(self.root.glob("*.zip")), [])

    def test_fast_verify_round_trips_through_the_cli(self) -> None:
        """--verify fast must still archive, verify names/sizes, and delete."""
        write_tree(self.root, {"a/1.txt": b"one", "a/sub/2.txt": b"two"})
        with captured_console():
            code = s.main(["-d", str(self.root), "-y", "--no-log", "--verify", "fast"])

        self.assertEqual(code, 0)
        self.assertFalse((self.root / "a").exists())
        with zipfile.ZipFile(self.root / "a.zip") as zf:
            self.assertIsNone(zf.testzip())
            self.assertEqual(sorted(zf.namelist()), ["1.txt", "sub/", "sub/2.txt"])

    def test_delete_mode_missing_directory_exits_nonzero(self) -> None:
        with captured_console():
            self.assertEqual(
                s.main(["-d", str(self.root / "does-not-exist"), "-y", "--no-log"]), 2
            )

    def test_deflate_round_trips_through_the_cli(self) -> None:
        """Covers the compression/level plumbing from argv down to the writer."""
        write_tree(self.root, {"a/1.txt": b"text " * 500})
        with captured_console():
            code = s.main(["-d", str(self.root), "-y", "--no-log", "-c", "deflate", "--level", "9"])

        self.assertEqual(code, 0)
        with zipfile.ZipFile(self.root / "a.zip") as zf:
            info = zf.getinfo("1.txt")
            self.assertEqual(info.compress_type, zipfile.ZIP_DEFLATED)
            self.assertLess(info.compress_size, info.file_size)
            self.assertEqual(zf.read("1.txt"), b"text " * 500)


class TestCli(TempRepo):
    def test_delete_requires_explicit_directory(self) -> None:
        """-d must never default to the cwd."""
        with self.assertRaises(SystemExit):
            s.build_parser().parse_args(["-d"])

    def test_list_and_delete_are_mutually_exclusive(self) -> None:
        with self.assertRaises(SystemExit):
            s.build_parser().parse_args(["-l", "x", "-d", "y"])

    def test_default_compression_is_store(self) -> None:
        self.assertEqual(s.build_parser().parse_args([]).compress, "store")

    def test_missing_directory_exits_nonzero(self) -> None:
        with captured_console():
            self.assertEqual(
                s.main(["-l", str(self.root / "does-not-exist"), "--no-log"]), 2
            )

    def test_zero_workers_rejected(self) -> None:
        with captured_console():
            self.assertEqual(s.main(["-l", str(self.root), "-w", "0", "--no-log"]), 2)

    def test_list_mode_on_empty_root_succeeds(self) -> None:
        with captured_console():
            self.assertEqual(s.main(["-l", str(self.root), "--no-log"]), 0)

    def test_list_mode_renders_a_table(self) -> None:
        write_tree(self.root, {"alpha/1.txt": b"x" * 10, "beta/2.txt": b"y" * 20})
        for sort in sorted(s.SORT_KEYS):
            with self.subTest(sort=sort), captured_console() as buf:
                self.assertEqual(s.main(["-l", str(self.root), "--no-log", "--sort", sort]), 0)
                out = buf.getvalue()
                self.assertIn("alpha", out)
                self.assertIn("beta", out)

    def test_out_of_range_level_is_rejected_before_any_work(self) -> None:
        """It used to surface per folder, mid-run, as a confusing zipfile error."""
        write_tree(self.root, {"a/1.txt": b"x"})
        for method, bad in (("deflate", 99), ("bzip2", 0)):
            with self.subTest(method=method), captured_console() as buf:
                code = s.main(
                    ["-d", str(self.root), "-y", "--no-log", "-c", method, "--level", str(bad)]
                )
                self.assertEqual(code, 2)
                self.assertIn("--level", buf.getvalue())
        self.assertTrue((self.root / "a" / "1.txt").exists(), "nothing may be touched")

    def test_level_boundaries_are_accepted(self) -> None:
        for method, level in (("deflate", 0), ("deflate", 9), ("bzip2", 1), ("bzip2", 9)):
            with self.subTest(method=method, level=level), captured_console():
                self.assertEqual(
                    s.main(["-l", str(self.root), "--no-log", "-c", method, "--level", str(level)]),
                    0,
                )

    def test_level_ranges_cover_every_method_that_takes_one(self) -> None:
        """Guards against adding a codec to one table but not the other."""
        takes_level = {n for n, (_c, lvl) in s.COMPRESSION_METHODS.items() if lvl}
        self.assertEqual(takes_level, set(s.LEVEL_RANGES))

    def test_level_on_a_method_without_levels_warns_but_proceeds(self) -> None:
        with captured_console() as buf:
            self.assertEqual(
                s.main(["-l", str(self.root), "--no-log", "-c", "store", "--level", "5"]), 0
            )
            self.assertIn("no effect", buf.getvalue())

    def test_extra_positional_path_is_rejected(self) -> None:
        """Silently ignoring it would look like the extra path had been processed."""
        with captured_console():
            self.assertEqual(s.main(["-l", str(self.root), "other", "--no-log"]), 2)
            self.assertEqual(s.main(["-d", str(self.root), "other", "-y", "--no-log"]), 2)

    def test_positional_path_alone_is_accepted(self) -> None:
        with captured_console():
            self.assertEqual(s.main([str(self.root), "--no-log"]), 0)

    def test_compression_methods_are_all_usable(self) -> None:
        """Guards the conditional zstd registration."""
        for name, (const, _lvl) in s.COMPRESSION_METHODS.items():
            with self.subTest(method=name):
                z = self.root / f"{name}.zip"
                with zipfile.ZipFile(z, "w", compression=const) as zf:
                    zf.writestr("a.txt", b"payload" * 100)
                with zipfile.ZipFile(z) as zf:
                    self.assertEqual(zf.read("a.txt"), b"payload" * 100)

    @unittest.skipUnless(s.ZSTD_AVAILABLE, "zstd requires Python 3.14+")
    def test_zstd_is_offered_when_available(self) -> None:
        self.assertEqual(s.build_parser().parse_args(["-c", "zstd"]).compress, "zstd")


if __name__ == "__main__":
    unittest.main(verbosity=2)
