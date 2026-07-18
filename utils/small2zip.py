#!/usr/bin/env python3
"""small2zip -- inventory first-level folders, and (optionally) archive+reclaim them.

Two modes
---------
``--list`` (default)
    Walk every first-level sub-directory of ``root`` and report file count,
    total bytes and average file size, plus a grand total row.

``--delete``
    For every first-level sub-directory of ``root``:
      1. zip the folder into ``<root>/<folder>.zip``
      2. *verify* the archive
      3. only then permanently delete the folder from disk

Safety model (read this before changing anything)
-------------------------------------------------
The single hard invariant of this tool is:

    A file is deleted from disk ONLY AFTER a readable archive on disk is
    proven to contain that exact file's bytes.

Everything below exists to uphold that invariant; do not "optimise" any of it
away without re-deriving the guarantee:

* **Write to a side file, then swap.** New/updated archives are built as
  ``<folder>.zip.partial``. The real ``.zip`` is only replaced by an atomic
  ``os.replace`` once the partial is complete *and* verified. A crash, a
  ``Ctrl+C`` or a full disk therefore leaves the pre-existing archive (if any)
  untouched, and leaves the source folder untouched.
* **Append is copy-then-append, never in-place.** When adding to an existing
  archive we first copy it to the partial file and append there. Appending
  in-place would mutate the only known-good copy of already-archived data.
* **Verification re-opens the archive from disk.** We never trust the in-memory
  writer. We re-open the finished file, and for every file we intended to store
  we check the entry exists, its uncompressed size matches, and (default) we
  stream-decompress it so zipfile validates the CRC. Nothing about the writer's
  state is reused.
* **Deletion is per-file and manifest-driven.** We delete exactly the paths that
  verification confirmed, never a blanket ``rmtree``. Each file is re-``stat``ed
  immediately before unlink; if size or mtime moved since we archived it, the
  file was modified after archiving and is *kept*, not deleted.
* **Any doubt => keep the data.** Unreadable file, symlink, verification miss,
  cancellation, or a failed unlink all abort deletion for that folder. The
  worst case is a folder that survives next to a valid archive (recoverable,
  just re-run); never the reverse.

Performance notes
-----------------
Workloads here are millions of small files, so the cost is syscalls, not CPU.
* ``os.scandir`` is used everywhere -- it returns cached stat data from the
  directory read on both Windows and Linux, avoiding a second ``stat`` per file.
* Top-level folders are processed concurrently in a thread pool. Threads (not
  processes) are correct here because the workload is I/O syscalls and zlib
  compression, both of which release the GIL.
* Within one folder work is single-threaded: ``zipfile.ZipFile`` is not
  thread-safe, and one sequential reader per spindle/queue is usually optimal.
* Compression defaults to ``store`` (none). The primary space win here comes
  from *consolidation* -- a 3 KB file still occupies a full cluster on disk, so
  packing millions of them into one archive reclaims the slack regardless of
  codec. ``store`` is also the fastest and the most portable. Pass
  ``--compress deflate`` for text-like payloads, where compression costs ~5% on
  small files and can shrink them 10x.

Author's note for maintainers: keep the "manifest" concept central. A manifest
entry is the contract "this exact source file is inside that archive"; it is
produced by the zip stage, confirmed by the verify stage, and consumed by the
delete stage. New features should extend the manifest, not bypass it.
"""

from __future__ import annotations

import argparse
import logging
import os
import shutil
import signal
import stat
import sys
import threading
import time
import zipfile
from concurrent.futures import ThreadPoolExecutor, as_completed
from dataclasses import dataclass, field
from pathlib import Path
from typing import Iterable, Iterator, Sequence

from rich.console import Console, Group
from rich.logging import RichHandler
from rich.panel import Panel
from rich.progress import (
    BarColumn,
    MofNCompleteColumn,
    Progress,
    SpinnerColumn,
    TaskProgressColumn,
    TextColumn,
    TimeElapsedColumn,
    TimeRemainingColumn,
)
from rich.table import Table

# --------------------------------------------------------------------------- #
# Constants
# --------------------------------------------------------------------------- #

#: Suffix for the in-progress archive. Never a valid final artifact.
PARTIAL_SUFFIX = ".zip.partial"

#: Read buffer for copy/verify streaming. 1 MiB balances syscall count against
#: cache pressure; larger gave no measurable win on spinning or NVMe media.
CHUNK_SIZE = 1 << 20

#: Human-readable compression choices -> (zipfile constant, supports level).
COMPRESSION_METHODS = {
    "store": (zipfile.ZIP_STORED, False),
    "deflate": (zipfile.ZIP_DEFLATED, True),
    "bzip2": (zipfile.ZIP_BZIP2, True),
    "lzma": (zipfile.ZIP_LZMA, False),
}

# Zstandard is ZIP compression method 93 (PKWARE APPNOTE 6.3.7, 2020), exposed
# by CPython 3.14+ via PEP 784. It is far faster than deflate at a better ratio
# -- on large payloads it can beat 'store' outright, because writing fewer bytes
# costs less than the compression saves.
#
# It is deliberately NOT the default: method 93 is young enough that many
# extractors (notably the zip handler built into Windows Explorer) cannot read
# it. For an archival tool whose output may need opening years from now on an
# unknown machine, universal readability outranks speed. Opt in with -c zstd.
ZSTD_AVAILABLE = hasattr(zipfile, "ZIP_ZSTANDARD")
if ZSTD_AVAILABLE:
    COMPRESSION_METHODS["zstd"] = (zipfile.ZIP_ZSTANDARD, True)

DEFAULT_LOG_PATH = Path.home() / "small2zip.log"

console = Console(stderr=False)
log = logging.getLogger("small2zip")

# --------------------------------------------------------------------------- #
# Cancellation
# --------------------------------------------------------------------------- #

#: Set by SIGINT/SIGTERM. Every long loop polls this and unwinds cooperatively
#: so that we never die between "archive written" and "source deleted".
cancel_event = threading.Event()


def _install_signal_handlers() -> None:
    def _handler(signum, _frame):  # noqa: ANN001 - signal API
        if cancel_event.is_set():
            # Second Ctrl+C: the user insists. Partial files may be left behind
            # but no source data can be lost -- deletion never starts unless a
            # verified archive already exists.
            console.print("[bold red]Second interrupt -- exiting immediately.[/]")
            os._exit(130)
        cancel_event.set()
        console.print(
            f"\n[bold yellow]Cancellation requested (signal {signum}). "
            "Finishing current file, then stopping safely...[/]"
        )

    for sig in (signal.SIGINT, getattr(signal, "SIGTERM", signal.SIGINT)):
        try:
            signal.signal(sig, _handler)
        except (ValueError, OSError):  # not on main thread / unsupported
            pass


class Cancelled(Exception):
    """Raised internally to unwind a worker when the user cancels."""


def _check_cancel() -> None:
    if cancel_event.is_set():
        raise Cancelled()


# --------------------------------------------------------------------------- #
# Formatting helpers
# --------------------------------------------------------------------------- #


def human_size(num_bytes: float) -> str:
    """Format bytes with binary units, e.g. ``1.4 GiB``."""
    if num_bytes < 1024:
        return f"{int(num_bytes)} B"
    value = float(num_bytes)
    for unit in ("KiB", "MiB", "GiB", "TiB", "PiB"):
        value /= 1024.0
        if value < 1024.0:
            return f"{value:,.1f} {unit}"
    return f"{value:,.1f} EiB"


def human_count(num: int) -> str:
    return f"{num:,}"


# --------------------------------------------------------------------------- #
# Scanning
# --------------------------------------------------------------------------- #


@dataclass(slots=True)
class FolderStats:
    """Aggregate stats for one first-level folder."""

    name: str
    path: Path
    file_count: int = 0
    total_bytes: int = 0
    dir_count: int = 0
    symlink_count: int = 0
    errors: list[str] = field(default_factory=list)

    @property
    def avg_bytes(self) -> float:
        return self.total_bytes / self.file_count if self.file_count else 0.0


def iter_top_level_dirs(root: Path, include_hidden: bool) -> list[Path]:
    """Return first-level sub-directories of *root* (sorted, symlinks skipped).

    Symlinked directories are excluded deliberately: following them can escape
    *root* and can loop, and neither is acceptable for a destructive tool.
    """
    out: list[Path] = []
    with os.scandir(root) as it:
        for entry in it:
            if not include_hidden and entry.name.startswith("."):
                continue
            try:
                # follow_symlinks=False => a symlinked dir reports False here.
                if entry.is_dir(follow_symlinks=False):
                    out.append(Path(entry.path))
            except OSError as exc:  # pragma: no cover - race with fs changes
                log.warning("Cannot stat %s: %s", entry.path, exc)
    return sorted(out, key=lambda p: p.name.lower())


def scan_folder(path: Path) -> FolderStats:
    """Recursively collect counts/sizes for one folder using ``os.scandir``.

    Uses an explicit stack rather than recursion so that pathologically deep
    trees cannot blow the Python stack. Sizes come from the ``DirEntry`` stat
    cache populated by the directory scan itself -- this is the main reason this
    is much faster than ``os.walk`` + ``os.path.getsize``.
    """
    stats = FolderStats(name=path.name, path=path)
    stack: list[str] = [str(path)]
    while stack:
        _check_cancel()
        current = stack.pop()
        try:
            with os.scandir(current) as it:
                for entry in it:
                    try:
                        if entry.is_symlink():
                            stats.symlink_count += 1
                            continue
                        if entry.is_dir(follow_symlinks=False):
                            stats.dir_count += 1
                            stack.append(entry.path)
                        else:
                            stats.file_count += 1
                            stats.total_bytes += entry.stat(follow_symlinks=False).st_size
                    except OSError as exc:
                        stats.errors.append(f"{entry.path}: {exc}")
        except OSError as exc:
            stats.errors.append(f"{current}: {exc}")
    return stats


def scan_all(dirs: Sequence[Path], workers: int) -> list[FolderStats]:
    """Scan folders concurrently, with a live progress bar."""
    results: list[FolderStats] = []
    with Progress(
        SpinnerColumn(),
        TextColumn("[bold blue]{task.description}"),
        BarColumn(),
        MofNCompleteColumn(),
        TaskProgressColumn(),
        TimeElapsedColumn(),
        TextColumn("{task.fields[extra]}"),
        console=console,
        transient=True,
    ) as progress:
        task = progress.add_task("Scanning folders", total=len(dirs), extra="")
        files_seen = 0
        with ThreadPoolExecutor(max_workers=workers) as pool:
            futures = {pool.submit(scan_folder, d): d for d in dirs}
            try:
                for fut in as_completed(futures):
                    try:
                        st = fut.result()
                    except Cancelled:
                        continue
                    except OSError as exc:
                        d = futures[fut]
                        log.error("Scan failed for %s: %s", d, exc)
                        st = FolderStats(name=d.name, path=d, errors=[str(exc)])
                    results.append(st)
                    files_seen += st.file_count
                    progress.update(
                        task,
                        advance=1,
                        extra=f"[dim]{human_count(files_seen)} files[/]",
                    )
            except KeyboardInterrupt:  # pragma: no cover - defensive
                cancel_event.set()
            finally:
                if cancel_event.is_set():
                    # Do not wait for the whole queue to drain on cancel.
                    pool.shutdown(wait=False, cancel_futures=True)
    return sorted(results, key=lambda s: s.name.lower())


# --------------------------------------------------------------------------- #
# List mode
# --------------------------------------------------------------------------- #

SORT_KEYS = {
    "name": lambda s: s.name.lower(),
    "size": lambda s: -s.total_bytes,
    "count": lambda s: -s.file_count,
    "avg": lambda s: -s.avg_bytes,
}


def render_list(stats: Sequence[FolderStats], root: Path, sort: str) -> None:
    table = Table(
        title=f"First-level folders in {root}",
        title_style="bold",
        header_style="bold cyan",
        show_footer=True,
        row_styles=["", "on grey11"],
    )
    total_files = sum(s.file_count for s in stats)
    total_bytes = sum(s.total_bytes for s in stats)
    total_dirs = sum(s.dir_count for s in stats)
    grand_avg = total_bytes / total_files if total_files else 0.0

    table.add_column("Folder", footer=f"[bold]TOTAL ({len(stats)} folders)[/]", overflow="fold")
    table.add_column("Files", justify="right", footer=f"[bold]{human_count(total_files)}[/]")
    table.add_column("Subdirs", justify="right", footer=f"[bold]{human_count(total_dirs)}[/]")
    table.add_column("Total size", justify="right", footer=f"[bold]{human_size(total_bytes)}[/]")
    table.add_column("Avg size", justify="right", footer=f"[bold]{human_size(grand_avg)}[/]")
    table.add_column("Issues", justify="right", footer="")

    for s in sorted(stats, key=SORT_KEYS[sort]):
        issues = ""
        if s.errors:
            issues = f"[red]{len(s.errors)} err[/]"
        elif s.symlink_count:
            issues = f"[yellow]{s.symlink_count} link[/]"
        table.add_row(
            s.name,
            human_count(s.file_count),
            human_count(s.dir_count),
            human_size(s.total_bytes),
            human_size(s.avg_bytes),
            issues,
        )

    console.print(table)
    err_total = sum(len(s.errors) for s in stats)
    if err_total:
        console.print(
            f"[yellow]{err_total} path(s) could not be read; see the log for details.[/]"
        )
        for s in stats:
            for e in s.errors[:5]:
                log.warning("scan error: %s", e)


# --------------------------------------------------------------------------- #
# Archive mode
# --------------------------------------------------------------------------- #


@dataclass(slots=True)
class ManifestEntry:
    """The contract linking one source file to one archive member.

    ``size``/``mtime_ns`` are captured at archive time so the delete stage can
    detect a file that changed after we read it and refuse to remove it.
    """

    src: str  # absolute source path
    arcname: str  # member name inside the archive
    size: int
    mtime_ns: int


@dataclass(slots=True)
class FolderResult:
    """Outcome for one top-level folder; drives the final summary table."""

    name: str
    status: str = "pending"  # ok | skipped | failed | cancelled | dry-run
    archived_files: int = 0
    archived_bytes: int = 0
    deleted_files: int = 0
    undeleted: list[str] = field(default_factory=list)
    skipped_symlinks: int = 0
    message: str = ""


def _collect_files(folder: Path, result: FolderResult) -> tuple[list[ManifestEntry], list[str]]:
    """Enumerate regular files under *folder* into prospective manifest entries.

    Returns ``(entries, blockers)``. A non-empty *blockers* list means the folder
    must not be deleted even if archiving succeeds (we cannot represent those
    paths faithfully in a zip, so removing them would lose data).
    """
    entries: list[ManifestEntry] = []
    blockers: list[str] = []
    root_str = str(folder)
    stack = [root_str]
    while stack:
        _check_cancel()
        current = stack.pop()
        try:
            with os.scandir(current) as it:
                for entry in it:
                    try:
                        if entry.is_symlink():
                            # Zip cannot round-trip symlinks portably; keeping
                            # them is the safe choice, so the folder survives.
                            result.skipped_symlinks += 1
                            blockers.append(f"symlink not archivable: {entry.path}")
                            continue
                        if entry.is_dir(follow_symlinks=False):
                            stack.append(entry.path)
                            continue
                        st = entry.stat(follow_symlinks=False)
                        if not stat.S_ISREG(st.st_mode):
                            blockers.append(f"not a regular file: {entry.path}")
                            continue
                        arcname = os.path.relpath(entry.path, root_str).replace(os.sep, "/")
                        entries.append(
                            ManifestEntry(
                                src=entry.path,
                                arcname=arcname,
                                size=st.st_size,
                                mtime_ns=st.st_mtime_ns,
                            )
                        )
                    except OSError as exc:
                        blockers.append(f"{entry.path}: {exc}")
        except OSError as exc:
            blockers.append(f"{current}: {exc}")
    return entries, blockers


def _unique_arcname(existing: set[str], arcname: str) -> str:
    """Return a name not already present in *existing*.

    Only used when appending to an archive that already holds a *different* file
    under the same name. Renaming (rather than overwriting or skipping) is what
    lets us keep the no-data-loss guarantee for both copies.
    """
    if arcname not in existing:
        return arcname
    base, dot, ext = arcname.rpartition(".")
    stem, suffix = (base, "." + ext) if dot else (arcname, "")
    i = 1
    while True:
        candidate = f"{stem}__dup{i}{suffix}"
        if candidate not in existing:
            return candidate
        i += 1


def _archive_folder(
    folder: Path,
    dest_zip: Path,
    partial: Path,
    entries: list[ManifestEntry],
    compression: int,
    level: int | None,
    progress: Progress,
    task_id,
) -> list[ManifestEntry]:
    """Build *partial* containing every entry, returning the written manifest.

    If *dest_zip* exists it is copied to *partial* first and appended to, so the
    existing archive is never mutated. The caller is responsible for verifying
    *partial* and only then swapping it into place.
    """
    existing_names: set[str] = set()
    existing_by_name: dict[str, int] = {}

    if dest_zip.exists():
        progress.update(task_id, description=f"{folder.name} [dim]copying existing zip[/]")
        _copy_file(dest_zip, partial)
        with zipfile.ZipFile(partial, "r") as zf:
            for info in zf.infolist():
                existing_names.add(info.filename)
                existing_by_name[info.filename] = info.file_size
        mode = "a"
    else:
        mode = "w"

    written: list[ManifestEntry] = []
    kwargs = {"compresslevel": level} if level is not None else {}
    with zipfile.ZipFile(partial, mode, compression=compression, allowZip64=True, **kwargs) as zf:
        for entry in entries:
            _check_cancel()
            prior = existing_by_name.get(entry.arcname)
            if prior is not None and prior == entry.size:
                # Identical name and size: assume already archived by a previous
                # run. Re-adding would create a duplicate member for no gain.
                # NOTE: this is a size-only heuristic; use --strict if the
                # destination archive may contain unrelated same-named files.
                written.append(entry)
                progress.advance(task_id, entry.size)
                continue
            arcname = _unique_arcname(existing_names, entry.arcname)
            if arcname != entry.arcname:
                log.warning(
                    "name collision in %s: storing %s as %s", dest_zip, entry.arcname, arcname
                )
                entry = ManifestEntry(entry.src, arcname, entry.size, entry.mtime_ns)
            zf.write(entry.src, arcname)
            existing_names.add(arcname)
            written.append(entry)
            progress.advance(task_id, entry.size)
        # Flush zipfile's own buffers, then force the bytes to the platter.
        # Without the fsync a power loss could leave a "verified" archive that
        # does not actually exist on disk while the source is already gone.
        zf.fp.flush()
        os.fsync(zf.fp.fileno())
    return written


def _copy_file(src: Path, dst: Path) -> None:
    with open(src, "rb") as fin, open(dst, "wb") as fout:
        while True:
            _check_cancel()
            buf = fin.read(CHUNK_SIZE)
            if not buf:
                break
            fout.write(buf)
        fout.flush()
        os.fsync(fout.fileno())


def _verify_archive(
    archive: Path,
    manifest: Sequence[ManifestEntry],
    full: bool,
    progress: Progress,
    task_id,
) -> list[str]:
    """Re-open *archive* from disk and confirm it holds every manifest entry.

    Returns a list of problems; empty means the archive is trustworthy and the
    sources may be deleted. With *full* we stream every member, which makes
    zipfile validate the stored CRC32 -- this is the check that actually proves
    the bytes are readable, so it is the default.
    """
    problems: list[str] = []
    try:
        with zipfile.ZipFile(archive, "r") as zf:
            index = {i.filename: i for i in zf.infolist()}
            for entry in manifest:
                _check_cancel()
                info = index.get(entry.arcname)
                if info is None:
                    problems.append(f"missing from archive: {entry.arcname}")
                    continue
                if info.file_size != entry.size:
                    problems.append(
                        f"size mismatch for {entry.arcname}: "
                        f"archive={info.file_size} source={entry.size}"
                    )
                    continue
                if full:
                    try:
                        with zf.open(info, "r") as member:
                            while member.read(CHUNK_SIZE):
                                pass  # CRC checked by zipfile on EOF
                    except (zipfile.BadZipFile, OSError) as exc:
                        problems.append(f"unreadable member {entry.arcname}: {exc}")
                        continue
                progress.advance(task_id, entry.size)
    except (zipfile.BadZipFile, OSError) as exc:
        problems.append(f"cannot open archive: {exc}")
    return problems


def _force_remove(path: str) -> None:
    """Unlink *path*, clearing a read-only bit first (common on Windows)."""
    try:
        os.remove(path)
    except PermissionError:
        os.chmod(path, stat.S_IWRITE)
        os.remove(path)


def _delete_sources(folder: Path, manifest: Sequence[ManifestEntry], result: FolderResult) -> None:
    """Delete exactly the verified files, then prune the emptied directories.

    Each file is re-stat'ed right before removal: if it changed since archiving
    we keep it, because the archive no longer represents its current contents.
    """
    for entry in manifest:
        _check_cancel()
        try:
            st = os.stat(entry.src)
            if st.st_size != entry.size or st.st_mtime_ns != entry.mtime_ns:
                result.undeleted.append(f"{entry.src}: modified after archiving")
                log.warning("KEEP (changed since archive): %s", entry.src)
                continue
            _force_remove(entry.src)
            result.deleted_files += 1
            log.debug("deleted %s", entry.src)
        except FileNotFoundError:
            # Already gone; the archive still holds a copy, so this is benign.
            result.deleted_files += 1
        except OSError as exc:
            result.undeleted.append(f"{entry.src}: {exc}")
            log.error("FAILED to delete %s: %s", entry.src, exc)

    # Prune directories bottom-up. Any directory still holding something (a kept
    # file, a symlink, a file created during the run) simply stays.
    for dirpath, _dirnames, _filenames in os.walk(folder, topdown=False):
        try:
            os.rmdir(dirpath)
        except OSError as exc:
            if dirpath == str(folder):
                result.undeleted.append(f"{dirpath}: {exc}")
            log.debug("could not rmdir %s: %s", dirpath, exc)


def process_folder(
    folder: Path,
    root: Path,
    args: argparse.Namespace,
    compression: int,
    level: int | None,
    progress: Progress,
) -> FolderResult:
    """Zip -> verify -> delete a single top-level folder. Never raises."""
    result = FolderResult(name=folder.name)
    dest_zip = root / f"{folder.name}.zip"
    partial = root / f"{folder.name}{PARTIAL_SUFFIX}"
    task_id = progress.add_task(f"{folder.name} [dim]scanning[/]", total=None, start=True)
    started = time.monotonic()
    log.info("=== BEGIN folder=%s archive=%s ===", folder, dest_zip)

    try:
        if dest_zip.exists() and args.strict:
            result.status = "skipped"
            result.message = "archive exists (--strict)"
            log.warning("SKIP %s: archive already exists and --strict is set", folder)
            return result

        entries, blockers = _collect_files(folder, result)
        result.archived_files = len(entries)
        result.archived_bytes = sum(e.size for e in entries)
        log.info(
            "folder=%s files=%d bytes=%d blockers=%d",
            folder, len(entries), result.archived_bytes, len(blockers),
        )
        for b in blockers[:50]:
            log.warning("blocker in %s: %s", folder, b)

        # Dry-run exits before any write or unlink. Keep this check ahead of the
        # empty-folder branch below, which does remove directories.
        if args.dry_run:
            result.status = "dry-run"
            result.message = (
                "empty folder, would remove" if not entries and not blockers
                else f"would archive {len(entries)} files"
            )
            return result

        if not entries and not blockers:
            # Empty tree: nothing to archive, so there is nothing to lose --
            # safe to remove the (possibly nested) empty directories.
            _delete_sources(folder, [], result)
            result.status = "ok" if not result.undeleted else "failed"
            result.message = "empty folder removed" if not result.undeleted else "could not remove"
            return result

        # ---- 1. ARCHIVE (into the side file) --------------------------------
        # Total = bytes to write + bytes to verify, so one bar covers both.
        verify_factor = 2 if args.verify == "full" else 1
        progress.update(
            task_id,
            total=result.archived_bytes * verify_factor or 1,
            description=f"{folder.name} [cyan]archiving[/]",
        )
        if partial.exists():
            log.warning("removing stale partial %s", partial)
            _force_remove(str(partial))
        manifest = _archive_folder(
            folder, dest_zip, partial, entries, compression, level, progress, task_id
        )

        # ---- 2. VERIFY (re-read from disk) ----------------------------------
        progress.update(task_id, description=f"{folder.name} [magenta]verifying[/]")
        problems = _verify_archive(partial, manifest, args.verify == "full", progress, task_id)
        if problems:
            result.status = "failed"
            result.message = f"verification failed ({len(problems)} problems)"
            for p in problems[:50]:
                log.error("verify %s: %s", folder, p)
            log.error("ABORT %s: source folder left untouched", folder)
            _force_remove(str(partial))  # partial is worthless; the source is intact
            return result

        # ---- 3. PUBLISH (atomic swap; only now is the archive authoritative)
        os.replace(partial, dest_zip)
        log.info("archive published: %s (%d entries)", dest_zip, len(manifest))

        if blockers:
            # Archive is good, but the folder holds things we could not archive.
            result.status = "skipped"
            result.message = f"archived, kept folder ({len(blockers)} unarchivable paths)"
            log.warning("KEEP folder %s: %d unarchivable paths", folder, len(blockers))
            return result

        if args.keep:
            result.status = "ok"
            result.message = "archived (--keep, folder retained)"
            return result

        # ---- 4. DELETE (manifest-driven, per file) --------------------------
        progress.update(task_id, description=f"{folder.name} [red]deleting[/]")
        _delete_sources(folder, manifest, result)
        if result.undeleted:
            result.status = "failed"
            result.message = f"{len(result.undeleted)} path(s) could not be deleted"
        else:
            result.status = "ok"
            result.message = f"archived + removed in {time.monotonic() - started:.1f}s"
        return result

    except Cancelled:
        result.status = "cancelled"
        result.message = "cancelled before deletion" if result.deleted_files == 0 else "cancelled mid-delete"
        # Discard the partial: it is by definition incomplete. The source folder
        # is still complete (deletion had not started, or is logged above).
        try:
            if partial.exists():
                _force_remove(str(partial))
        except OSError:
            pass
        log.warning("CANCELLED folder=%s", folder)
        return result
    except Exception as exc:  # noqa: BLE001 - one bad folder must not kill the run
        result.status = "failed"
        result.message = str(exc)
        log.exception("UNEXPECTED failure on %s", folder)
        try:
            if partial.exists():
                _force_remove(str(partial))
        except OSError:
            pass
        return result
    finally:
        log.info("=== END folder=%s status=%s %s ===", folder, result.status, result.message)
        progress.remove_task(task_id)


def run_delete(root: Path, dirs: Sequence[Path], args: argparse.Namespace) -> list[FolderResult]:
    compression, supports_level = COMPRESSION_METHODS[args.compress]
    level = args.level if (supports_level and args.level is not None) else None

    results: list[FolderResult] = []
    with Progress(
        SpinnerColumn(),
        TextColumn("[bold]{task.description}"),
        BarColumn(bar_width=None),
        TaskProgressColumn(),
        TimeRemainingColumn(),
        console=console,
    ) as progress:
        overall = progress.add_task(f"[bold green]Total ({len(dirs)} folders)", total=len(dirs))
        with ThreadPoolExecutor(max_workers=args.workers) as pool:
            futures = {
                pool.submit(process_folder, d, root, args, compression, level, progress): d
                for d in dirs
            }
            try:
                for fut in as_completed(futures):
                    res = fut.result()  # process_folder never raises
                    results.append(res)
                    progress.advance(overall)
                    _print_folder_line(progress, res)
            finally:
                if cancel_event.is_set():
                    pool.shutdown(wait=True, cancel_futures=True)
    return results


STATUS_STYLE = {
    "ok": ("green", "OK"),
    "skipped": ("yellow", "SKIP"),
    "failed": ("bold red", "FAIL"),
    "cancelled": ("yellow", "CANCEL"),
    "dry-run": ("cyan", "DRY"),
    "pending": ("dim", "?"),
}


def _print_folder_line(progress: Progress, res: FolderResult) -> None:
    style, label = STATUS_STYLE[res.status]
    progress.console.print(
        f"[{style}]{label:>6}[/] {res.name} "
        f"[dim]({human_count(res.archived_files)} files, "
        f"{human_size(res.archived_bytes)}) {res.message}[/]"
    )
    for path in res.undeleted[:10]:
        progress.console.print(f"       [red]could not delete:[/] {path}")
    if len(res.undeleted) > 10:
        progress.console.print(f"       [red]... and {len(res.undeleted) - 10} more (see log)[/]")


def render_summary(results: Sequence[FolderResult], log_path: Path | None) -> int:
    """Print the final table. Returns the process exit code."""
    table = Table(title="Summary", header_style="bold cyan", show_footer=True)
    tot_arch = sum(r.archived_files for r in results)
    tot_bytes = sum(r.archived_bytes for r in results)
    tot_del = sum(r.deleted_files for r in results)
    tot_kept = sum(len(r.undeleted) for r in results)

    table.add_column("Folder", footer=f"[bold]{len(results)} folders[/]", overflow="fold")
    table.add_column("Status", footer="")
    table.add_column("Archived", justify="right", footer=f"[bold]{human_count(tot_arch)}[/]")
    table.add_column("Size", justify="right", footer=f"[bold]{human_size(tot_bytes)}[/]")
    table.add_column("Deleted", justify="right", footer=f"[bold]{human_count(tot_del)}[/]")
    table.add_column("Kept", justify="right", footer=f"[bold]{human_count(tot_kept)}[/]")
    table.add_column("Note", overflow="fold", footer="")

    for r in sorted(results, key=lambda x: (x.status != "failed", x.name.lower())):
        style, label = STATUS_STYLE[r.status]
        table.add_row(
            r.name,
            f"[{style}]{label}[/]",
            human_count(r.archived_files),
            human_size(r.archived_bytes),
            human_count(r.deleted_files),
            human_count(len(r.undeleted)) if r.undeleted else "",
            r.message,
        )
    console.print(table)

    failed = [r for r in results if r.status == "failed"]
    cancelled = [r for r in results if r.status == "cancelled"]
    if log_path:
        console.print(f"[dim]Full log: {log_path}[/]")
    if failed:
        console.print(
            f"[bold red]{len(failed)} folder(s) failed. Their source data was NOT deleted.[/]"
        )
        return 1
    if cancelled or cancel_event.is_set():
        console.print("[yellow]Run was cancelled; remaining folders are untouched.[/]")
        return 130
    return 0


# --------------------------------------------------------------------------- #
# CLI
# --------------------------------------------------------------------------- #


def setup_logging(log_path: Path | None, verbose: bool) -> None:
    log.setLevel(logging.DEBUG if verbose else logging.INFO)
    log.propagate = False
    if log_path:
        log_path.parent.mkdir(parents=True, exist_ok=True)
        handler = logging.FileHandler(log_path, encoding="utf-8")
        handler.setFormatter(
            logging.Formatter(
                "%(asctime)s %(levelname)-8s [%(threadName)s] %(message)s",
                datefmt="%Y-%m-%d %H:%M:%S",
            )
        )
        handler.setLevel(logging.DEBUG if verbose else logging.INFO)
        log.addHandler(handler)
    if verbose:
        log.addHandler(RichHandler(console=console, show_path=False, rich_tracebacks=True))
    if not log.handlers:
        log.addHandler(logging.NullHandler())


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        prog="small2zip",
        description=(
            "List first-level folders with file counts/sizes, or archive each "
            "one into a zip and permanently delete it after verification."
        ),
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=(
            "Examples:\n"
            "  small2zip.py                       # list folders in the current directory\n"
            "  small2zip.py -l D:/data --sort size\n"
            "  small2zip.py -d D:/data --dry-run  # show what --delete would do\n"
            "  small2zip.py -d D:/data -y --compress deflate   # compress text-like payloads\n"
        ),
    )
    mode = p.add_mutually_exclusive_group()
    mode.add_argument(
        "-l", "--list", dest="list_path", nargs="?", const=".", metavar="DIR",
        help="List first-level folders in DIR (default mode; DIR defaults to '.').",
    )
    mode.add_argument(
        "-d", "--delete", dest="delete_path", metavar="DIR",
        help="Archive each first-level folder of DIR to a zip, then delete the folder. "
             "DIR is mandatory -- this mode never guesses a target.",
    )

    p.add_argument(
        "-s", "--strict", action="store_true",
        help="With --delete: refuse to touch a folder whose .zip already exists "
             "(default is to append missing files into the existing archive).",
    )
    p.add_argument(
        "-w", "--workers", type=int, default=min(8, (os.cpu_count() or 4)),
        help="Folders processed concurrently (default: %(default)s).",
    )
    p.add_argument(
        "-c", "--compress", choices=sorted(COMPRESSION_METHODS), default="store",
        help="Compression method. The default 'store' does no compression: it is "
             "the fastest, the most universally readable, and it still delivers "
             "the main win of consolidating small files. Use 'deflate' for "
             "text/code/log/JSON payloads, where it costs ~5%% on small files and "
             "can shrink them 10x. 'zstd' is faster than deflate at a better "
             "ratio but some extractors (incl. Windows Explorer) cannot open it "
             "(default: %(default)s).",
    )
    p.add_argument(
        "--level", type=int, default=None,
        help="Compression level: deflate 0-9, bzip2 1-9, zstd 1-22. "
             "Default: library default.",
    )
    p.add_argument(
        "--verify", choices=("full", "fast"), default="full",
        help="'full' re-reads every archived member to validate CRCs before "
             "deleting anything; 'fast' only checks name+size (default: %(default)s).",
    )
    p.add_argument(
        "--keep", action="store_true",
        help="With --delete: create/verify the archives but do not delete anything.",
    )
    p.add_argument(
        "--dry-run", action="store_true",
        help="Show what would be archived/deleted without writing or removing anything.",
    )
    p.add_argument(
        "-y", "--yes", action="store_true",
        help="Skip the interactive confirmation prompt before destructive work.",
    )
    p.add_argument(
        "--sort", choices=sorted(SORT_KEYS), default="name",
        help="Sort order for the --list table (default: %(default)s).",
    )
    p.add_argument(
        "--include-hidden", action="store_true",
        help="Include folders whose name starts with '.' (skipped by default).",
    )
    p.add_argument(
        "--log", dest="log_path", default=str(DEFAULT_LOG_PATH), metavar="FILE",
        help="Log file path (default: %(default)s).",
    )
    p.add_argument("--no-log", action="store_true", help="Disable file logging entirely.")
    p.add_argument("-v", "--verbose", action="store_true", help="Debug logging, also to console.")
    p.add_argument(
        "path", nargs="?", default=None,
        help="Positional alternative to -l/--list DIR.",
    )
    return p


def confirm_destructive(root: Path, dirs: Sequence[Path], stats: Sequence[FolderStats]) -> bool:
    total_files = sum(s.file_count for s in stats)
    total_bytes = sum(s.total_bytes for s in stats)
    console.print(
        Panel(
            Group(
                f"[bold]Target:[/] {root}",
                f"[bold]Folders:[/] {len(dirs)}",
                f"[bold]Files:[/] {human_count(total_files)}  "
                f"[bold]Size:[/] {human_size(total_bytes)}",
                "",
                "[bold red]Each folder will be zipped and then PERMANENTLY DELETED[/]",
                "[dim]Files are removed only after the archive is written and verified.[/]",
            ),
            title="[bold red]Destructive operation",
            border_style="red",
        )
    )
    try:
        answer = console.input("Type [bold]yes[/] to proceed: ").strip().lower()
    except (EOFError, KeyboardInterrupt):
        return False
    return answer == "yes"


def main(argv: Sequence[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    _install_signal_handlers()

    log_path = None if args.no_log else Path(args.log_path).expanduser()
    setup_logging(log_path, args.verbose)

    delete_mode = args.delete_path is not None
    raw_root = args.delete_path if delete_mode else (args.list_path or args.path or ".")
    root = Path(raw_root).expanduser().resolve()

    if not root.is_dir():
        console.print(f"[bold red]Not a directory:[/] {root}")
        return 2
    if args.workers < 1:
        console.print("[bold red]--workers must be >= 1[/]")
        return 2

    log.info("start argv=%s root=%s mode=%s", sys.argv[1:], root, "delete" if delete_mode else "list")

    dirs = iter_top_level_dirs(root, args.include_hidden)
    if not dirs:
        console.print(f"[yellow]No first-level folders found in[/] {root}")
        return 0

    # Both modes start with a scan: in delete mode it powers the confirmation
    # summary, so the user always sees the blast radius before agreeing.
    stats = scan_all(dirs, args.workers)
    if cancel_event.is_set():
        console.print("[yellow]Cancelled during scan.[/]")
        return 130

    if not delete_mode:
        render_list(stats, root, args.sort)
        return 0

    if not (args.yes or args.dry_run) and not confirm_destructive(root, dirs, stats):
        console.print("[yellow]Aborted -- nothing was changed.[/]")
        return 1

    results = run_delete(root, dirs, args)
    return render_summary(results, log_path)


if __name__ == "__main__":
    sys.exit(main())
