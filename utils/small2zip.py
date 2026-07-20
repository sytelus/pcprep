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

``--small`` (``-s DIR``, or ``-d DIR -s``)
    Archive only directories dominated by small files: a directory qualifies
    when its subtree holds at least ``--small-files`` files with an average
    size of at most ``--small-avg`` KiB. A directory that does not qualify is
    kept, but its sub-directories are examined recursively and qualifying
    subtrees at any depth go through the same zip -> verify -> delete pipeline,
    each zip written next to its directory. The selection is shown and
    confirmed before anything is touched; ``-q`` skips the table (the
    confirmation totals remain), ``--dry-run`` shows the table and stops.

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
* **"Already archived" is decided by content, not by size.** When appending, a
  source is skipped only if a stored member has both the same size *and* the
  same CRC32. Matching on size alone would let an in-place edit of unchanged
  length be mistaken for the archived copy, and the source would then be deleted
  while the archive still held the stale bytes. The check scans the whole
  ``name``/``name__dup1``/``name__dup2`` sequence, not just the exact name, so a
  file stored under a collision name on an earlier run is recognised on the next
  one instead of being appended again (see ``_find_or_place``).
* **The manifest describes what was stored, not what was scanned.** File
  members re-check size/mtime on the open handle at write time, so a source
  that changed after the pre-scan is archived as it is *now*, and verification
  and deletion judge those recorded values -- never a stale snapshot.
* **Verification re-opens the archive from disk.** We never trust the in-memory
  writer. We re-open the finished file, and for every file we intended to store
  we check the entry exists, its uncompressed size matches, and (default) we
  stream-decompress it so zipfile validates the CRC. Nothing about the writer's
  state is reused.
* **Deletion is per-file and manifest-driven.** We delete exactly the paths that
  verification confirmed, never a blanket ``rmtree``. Each file is re-``stat``ed
  immediately before unlink; if size or mtime moved since we archived it, the
  file was modified after archiving and is *kept*, not deleted.
* **Directories are archived, not just walked through.** Every sub-directory
  gets its own zero-length member carrying its attributes. Without them an empty
  directory would have no representation in the archive at all -- yet the prune
  step would still remove it, destroying structure we never copied. Attributes
  (Unix mode *and* the DOS read-only/hidden/system bits) are stored for files
  and directories alike, and verification confirms them before any deletion:
  this tool must not promise retention it has not checked.
* **Nothing that points elsewhere is ever followed.** Symlinks *and* Windows
  junctions are refused, because archiving through one would then delete files
  outside the folder we were asked to process. Deletion walks the manifest, not
  ``os.walk``, for the same reason. Metadata zip simply cannot hold (ACLs,
  alternate data streams, owner/group) is *not* treated this way: it is dropped
  and the folder is still reclaimed, because the guarantee is about contents.
* **Any doubt => keep the data.** Unreadable file, symlink, junction,
  verification miss, cancellation, or a failed unlink all abort deletion for
  that folder. The worst case is a folder that survives next to a valid archive
  (recoverable, just re-run); never the reverse.

Performance notes
-----------------
Workloads here are millions of small files, so the cost is syscalls, not CPU.
* ``os.scandir`` is used everywhere -- it returns cached stat data from the
  directory read on both Windows and Linux, avoiding a second ``stat`` per file.
* The delete pipeline walks the tree exactly once. The pre-scan caches both
  per-directory aggregates and the full per-file enumeration (path, size,
  mtime, attributes); ``--small`` selection and the archive stage replay it
  from RAM (``_entries_from_tree``) instead of re-walking the disk. This
  deliberately trades memory for syscalls -- roughly 0.5 GB per million files
  -- because target machines are assumed to have RAM to spare. Safety never
  rests on the cache's age: the delete stage still re-``stat``s every file
  immediately before its unlink.
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
import zlib
from concurrent.futures import ThreadPoolExecutor, as_completed
from dataclasses import dataclass, field, replace
from pathlib import Path
from typing import Iterator, Sequence

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

#: Valid ``--level`` range per method. Validated up front because the underlying
#: libraries reject a bad level *while closing the archive*, which surfaces as a
#: baffling "Can't close the ZIP file while there is an open writing handle"
#: rather than "bad level" -- and it would do so once per folder, mid-run.
LEVEL_RANGES = {
    "deflate": (0, 9),
    "bzip2": (1, 9),
    "zstd": (-7, 22),  # negative levels are zstd's "faster than fast" modes
}

#: --small defaults: "at least this many files, at most this average size".
SMALL_MIN_FILES_DEFAULT = 50_000
SMALL_MAX_AVG_KIB_DEFAULT = 500

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

    # SIGBREAK is Windows' Ctrl+Break. Without it that keystroke bypasses this
    # handler entirely: the OS kills the process at STATUS_CONTROL_C_EXIT, so
    # nothing unwinds and stale .partial files are left behind. (No data can be
    # lost either way -- deletion never starts without a verified archive -- but
    # a clean exit is much easier to reason about.)
    signals = {signal.SIGINT}
    for name in ("SIGTERM", "SIGBREAK"):
        sig = getattr(signal, name, None)
        if sig is not None:
            signals.add(sig)
    for sig in signals:
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
    unit = ""
    for unit in ("KiB", "MiB", "GiB", "TiB", "PiB", "EiB", "ZiB", "YiB"):
        value /= 1024.0
        if value < 1024.0:
            return f"{value:,.1f} {unit}"
    # Falling out means the value is still >= 1024 after scaling to the largest
    # unit, so report it there. The bug this replaced labelled the value with
    # the *next* unit up without dividing, reporting 1 EiB as "1,024.0 EiB".
    return f"{value:,.1f} {unit}"


def human_count(num: int) -> str:
    return f"{num:,}"


def _display_name(path: Path, root: Path) -> str:
    """Path as shown in progress lines and tables: relative to *root* if under it."""
    try:
        return str(path.relative_to(root))
    except ValueError:  # defensive: never expected for paths we selected
        return str(path)


# --------------------------------------------------------------------------- #
# Scanning
# --------------------------------------------------------------------------- #


def _is_reparse_point(st: os.stat_result) -> bool:
    """True for a Windows reparse point (junction, mount point, symlink).

    ``DirEntry.is_symlink()`` returns **False** for a junction -- CPython treats
    only the symlink reparse tag as a link. A junction therefore looked like an
    ordinary directory: this tool recursed through it, archived whatever it
    pointed at, and then deleted those files, *outside* the folder it was told
    to process. Reparse points are excluded wholesale for exactly the reason
    symlinks are -- they can escape the tree and they can loop.

    Always False on POSIX, where the symlink check already covers this.
    """
    return bool(
        getattr(st, "st_file_attributes", 0)
        & getattr(stat, "FILE_ATTRIBUTE_REPARSE_POINT", 0)
    )


def _is_link_like(entry: os.DirEntry) -> bool:
    """True if *entry* must not be followed or archived (symlink or junction)."""
    if entry.is_symlink():
        return True
    try:
        return _is_reparse_point(entry.stat(follow_symlinks=False))
    except OSError:
        return False  # caller's own stat will surface the error


def iter_top_level_dirs(root: Path, include_hidden: bool) -> list[Path]:
    """Return first-level sub-directories of *root* (sorted, links skipped).

    Symlinked and junctioned directories are excluded deliberately: following
    them can escape *root* and can loop, and neither is acceptable for a
    destructive tool.
    """
    out: list[Path] = []
    with os.scandir(root) as it:
        for entry in it:
            if not include_hidden and entry.name.startswith("."):
                continue
            try:
                # follow_symlinks=False => a symlinked dir reports False here,
                # but a junction still reports True -- hence _is_link_like.
                if entry.is_dir(follow_symlinks=False) and not _is_link_like(entry):
                    out.append(Path(entry.path))
            except OSError as exc:  # pragma: no cover - race with fs changes
                log.warning("Cannot stat %s: %s", entry.path, exc)
    return sorted(out, key=lambda p: p.name.lower())


# --------------------------------------------------------------------------- #
# List mode
# --------------------------------------------------------------------------- #

SORT_KEYS = {
    "name": lambda n: n.path.name.lower(),
    "size": lambda n: -n.total_bytes,
    "count": lambda n: -n.file_count,
    "avg": lambda n: -n.avg_bytes,
}


def render_list(nodes: Sequence["DirNode"], root: Path, sort: str) -> None:
    table = Table(
        title=f"First-level folders in {root}",
        title_style="bold",
        header_style="bold cyan",
        show_footer=True,
        row_styles=["", "on grey11"],
    )
    total_files = sum(n.file_count for n in nodes)
    total_bytes = sum(n.total_bytes for n in nodes)
    total_dirs = sum(n.dir_count for n in nodes)
    grand_avg = total_bytes / total_files if total_files else 0.0

    table.add_column("Folder", footer=f"[bold]TOTAL ({len(nodes)} folders)[/]", overflow="fold")
    table.add_column("Files", justify="right", footer=f"[bold]{human_count(total_files)}[/]")
    table.add_column("Subdirs", justify="right", footer=f"[bold]{human_count(total_dirs)}[/]")
    table.add_column("Total size", justify="right", footer=f"[bold]{human_size(total_bytes)}[/]")
    table.add_column("Avg size", justify="right", footer=f"[bold]{human_size(grand_avg)}[/]")
    table.add_column("Issues", justify="right", footer="")

    for n in sorted(nodes, key=SORT_KEYS[sort]):
        if n.errors:
            issues = f"[red]{n.errors} err[/]"
        elif n.links:
            issues = f"[yellow]{n.links} link[/]"
        else:
            issues = ""
        table.add_row(
            n.path.name,
            human_count(n.file_count),
            human_count(n.dir_count),
            human_size(n.total_bytes),
            human_size(n.avg_bytes),
            issues,
        )

    console.print(table)
    err_total = sum(n.errors for n in nodes)
    if err_total:
        # Per-path details were logged by the walker as it hit them.
        console.print(
            f"[yellow]{err_total} path(s) could not be read; see the log for details.[/]"
        )


# --------------------------------------------------------------------------- #
# Small-folder selection (--small)
# --------------------------------------------------------------------------- #


@dataclass(slots=True)
class DirNode:
    """Recursive stats plus cached enumeration for one directory.

    ``file_count`` / ``total_bytes`` / ``dir_count`` / ``links`` are SUBTREE
    totals once ``_scan_dir_tree`` has aggregated them; ``children`` keeps the
    tree so ``--small`` selection can descend into directories that do not meet
    the criteria themselves.

    ``files`` and ``blockers`` are DIRECT (this directory only) and hold the
    per-entry data the manifest needs, so the archive stage can replay the
    enumeration from RAM instead of re-walking the disk -- see
    ``_entries_from_tree``. That trades memory for syscalls deliberately: this
    tool assumes machines with plenty of RAM (see README, Performance).
    ``mtime_ns``/``external_attr`` are this directory's own stat fields,
    captured by its parent's scan, for its manifest entry.
    """

    path: Path
    hidden: bool = False
    collected: bool = False
    mtime_ns: int = 0
    external_attr: int = 0
    file_count: int = 0
    total_bytes: int = 0
    dir_count: int = 0
    links: int = 0
    errors: int = 0
    #: Subtree count of ``blockers`` entries (meaningful only when collected).
    #: --small selection refuses directories where this is non-zero: they can
    #: be archived but never deleted, so selecting them would never converge.
    blocker_count: int = 0
    files: list[ManifestEntry] = field(default_factory=list)
    blockers: list[str] = field(default_factory=list)
    children: list["DirNode"] = field(default_factory=list)

    @property
    def avg_bytes(self) -> float:
        return self.total_bytes / self.file_count if self.file_count else 0.0


def _scan_dir_tree(top: Path, collect: bool = True) -> DirNode:
    """Build recursive stats -- and, with *collect*, the archive enumeration --
    for *top* in ONE walk. This is the module's only directory walker.

    One pass with an explicit stack (no recursion limit to blow, and
    ``scandir`` returns stat data cached from the directory read itself), then
    a bottom-up aggregation. The walk order guarantees parents are visited
    before their children, so iterating the visit list in reverse folds each
    child into its parent before the parent itself is folded upward -- no
    subtree is ever scanned or summed twice.

    ``collect=False`` (list mode) keeps only the counters, so listing a huge
    volume does not pay the enumeration cache's memory bill; such a tree
    cannot feed the archive stage (``_entries_from_tree`` refuses it).

    Link-like entries (symlinks, junctions) are counted but never followed --
    files behind them must not make a directory look archive-worthy when
    archiving would refuse to touch them anyway -- and they block deletion of
    their folder: zip cannot round-trip them, and following one would let us
    archive-then-delete files outside the tree entirely. Non-regular files
    (FIFOs, devices) count toward the listing totals but are blockers too.
    """
    root = DirNode(path=top, hidden=top.name.startswith("."), collected=collect)
    visited = [root]
    stack = [root]
    while stack:
        _check_cancel()
        node = stack.pop()
        try:
            with os.scandir(node.path) as it:
                for entry in it:
                    try:
                        if _is_link_like(entry):
                            node.links += 1
                            if collect:
                                node.blockers.append(
                                    f"symlink or junction not archivable: {entry.path}"
                                )
                            continue
                        st = entry.stat(follow_symlinks=False)
                        if entry.is_dir(follow_symlinks=False):
                            child = DirNode(
                                path=Path(entry.path),
                                hidden=entry.name.startswith("."),
                                collected=collect,
                                mtime_ns=st.st_mtime_ns,
                                external_attr=_external_attr(st, True),
                            )
                            node.children.append(child)
                            visited.append(child)
                            stack.append(child)
                        else:
                            node.file_count += 1
                            node.total_bytes += st.st_size
                            if not stat.S_ISREG(st.st_mode):
                                if collect:
                                    node.blockers.append(f"not a regular file: {entry.path}")
                            elif collect:
                                node.files.append(
                                    ManifestEntry(
                                        src=entry.path,
                                        arcname="",  # relative to a folder chosen later
                                        size=st.st_size,
                                        mtime_ns=st.st_mtime_ns,
                                        external_attr=_external_attr(st, False),
                                    )
                                )
                    except OSError as exc:
                        node.errors += 1
                        if collect:
                            node.blockers.append(f"{entry.path}: {exc}")
                        log.warning("scan: %s: %s", entry.path, exc)
        except OSError as exc:
            node.errors += 1
            if collect:
                node.blockers.append(f"{node.path}: {exc}")
            log.warning("scan: %s: %s", node.path, exc)
    for node in reversed(visited):  # children first, then their parents
        node.blocker_count = len(node.blockers)
        for child in node.children:
            node.file_count += child.file_count
            node.total_bytes += child.total_bytes
            node.dir_count += child.dir_count + 1
            node.links += child.links
            node.errors += child.errors
            node.blocker_count += child.blocker_count
    return root


def _entries_from_tree(node: DirNode, result: FolderResult) -> tuple[list[ManifestEntry], list[str]]:
    """Materialise the manifest for *node*'s folder from its scanned tree.

    Returns ``(entries, blockers)``. A non-empty *blockers* list means the
    folder must not be deleted even if archiving succeeds -- it holds paths a
    zip cannot represent faithfully, or paths that could not be read, and
    removing the folder would lose them. Sub-directories get their own entries
    so that empty ones survive and every directory's attributes are carried;
    the folder itself is not an entry: it is what the archive as a whole
    represents, and leaving it out keeps a genuinely empty folder archive-free.

    Zero disk I/O: the tree already holds every stat field a live walk would
    have captured, so downstream safety checks (the size+CRC skip test,
    verification, the re-stat before each delete) behave identically -- the
    data is just as old as the scan, and the delete-stage re-stat is what
    guards against that age.
    """
    if not node.collected:
        raise ValueError(f"tree for {node.path} was scanned without enumeration")
    entries: list[ManifestEntry] = []
    blockers: list[str] = []
    root_str = str(node.path)
    # A drive root's str ends in its separator ("C:\\", "/"); anything else
    # needs one skipped. The CLI never processes a filesystem root, but an API
    # caller might hand one to process_folder directly.
    prefix = len(root_str) + (0 if root_str.endswith(os.sep) else 1)
    result.skipped_symlinks += node.links
    stack = [node]
    while stack:
        _check_cancel()
        n = stack.pop()
        blockers.extend(n.blockers)
        for child in n.children:
            arcname = str(child.path)[prefix:].replace(os.sep, "/") + "/"
            entries.append(
                ManifestEntry(
                    src=str(child.path), arcname=arcname, size=0,
                    mtime_ns=child.mtime_ns, is_dir=True,
                    external_attr=child.external_attr,
                )
            )
            stack.append(child)
        for f in n.files:
            entries.append(replace(f, arcname=f.src[prefix:].replace(os.sep, "/")))
    # Directories first, then files, each sorted: dir members precede their
    # contents (what extractors expect) and archives become reproducible.
    entries.sort(key=lambda e: (not e.is_dir, e.arcname))
    return entries, blockers


def select_small_dirs(
    roots: Sequence[DirNode],
    min_files: int,
    max_avg_bytes: int,
    include_hidden: bool,
) -> tuple[list[DirNode], int]:
    """Pick the HIGHEST directories meeting the --small criteria.

    Returns ``(selected, blocked)``. *blocked* counts directories that met the
    size criteria but were set aside because their subtree contains
    unarchivable paths (symlinks, junctions, unreadable or non-regular files).
    Selecting one could never reclaim it: process_folder would archive it and
    then keep the folder, and every rerun would re-copy and re-verify a
    growing archive without ever converging. Their clean sub-directories are
    examined instead.

    A selected directory is archived whole, so selection never descends into
    it -- selected subtrees are therefore always disjoint, which is what makes
    processing them concurrently safe. A directory that does not qualify is
    never archived itself; only its children are examined.

    Hidden directories are not candidates unless *include_hidden* (matching how
    top-level dot-folders are treated), but their contents still count toward
    every ancestor's totals -- candidacy is filtered, statistics are not.
    """
    selected: list[DirNode] = []
    blocked = 0
    stack = list(roots)
    while stack:
        node = stack.pop()
        qualifies = node.file_count >= min_files and node.avg_bytes <= max_avg_bytes
        if qualifies and node.blocker_count == 0:
            selected.append(node)
            continue
        if qualifies:
            blocked += 1  # size says yes; contents say it can never be reclaimed
        stack.extend(c for c in node.children if include_hidden or not c.hidden)
    return sorted(selected, key=lambda n: str(n.path).lower()), blocked


def scan_dir_trees(dirs: Sequence[Path], workers: int, collect: bool = True) -> list[DirNode]:
    """Scan each top-level folder's subtree once, concurrently.

    The returned trees feed everything downstream without another walk:
    ``--small`` selection reads the aggregates, the confirmation summary and
    the ``--list`` table read the totals, and the archive stage replays the
    cached enumeration (``_entries_from_tree``). List mode passes
    ``collect=False`` to skip the enumeration cache it does not need.
    """
    roots: list[DirNode] = []
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
            futures = {pool.submit(_scan_dir_tree, d, collect): d for d in dirs}
            try:
                for fut in as_completed(futures):
                    try:
                        node = fut.result()
                    except Cancelled:
                        continue
                    roots.append(node)
                    files_seen += node.file_count
                    progress.update(
                        task,
                        advance=1,
                        extra=f"[dim]{human_count(files_seen)} files[/]",
                    )
            except KeyboardInterrupt:  # pragma: no cover - embedders w/o handler
                cancel_event.set()
            finally:
                if cancel_event.is_set():
                    # Drop everything still queued. Threads already running are
                    # not killable, but they poll _check_cancel and unwind fast;
                    # the enclosing `with` then joins them.
                    pool.shutdown(wait=False, cancel_futures=True)
    return sorted(roots, key=lambda n: n.path.name.lower())


def render_small_selection(
    root: Path,
    selected: Sequence[DirNode],
    min_files: int,
    max_avg_bytes: int,
    dry_run: bool,
    keep: bool = False,
) -> None:
    """Show exactly which directories --small picked, with their stats.

    This is the blast radius: under ``--dry-run`` it is the entire output, and
    in a real run it is what the user is about to confirm.
    """
    criteria = f">= {human_count(min_files)} files, average <= {human_size(max_avg_bytes)}"
    if not selected:
        console.print(
            f"[yellow]No directory under[/] {root} [yellow]meets the --small criteria "
            f"({criteria}). Nothing to do.[/]"
        )
        return

    act = "archive (--keep: nothing deleted)" if keep else "archive + delete"
    verb = f"would {act}" if dry_run else f"will {act}"
    noun = "directory" if len(selected) == 1 else "directories"
    table = Table(
        title=f"--small {verb} {len(selected)} {noun}\n[dim]criteria: {criteria}[/]",
        title_style="bold",
        header_style="bold cyan",
        show_footer=True,
        row_styles=["", "on grey11"],
        caption="Directories not listed are left untouched. "
                "Each archive is written next to its directory.",
    )
    total_files = sum(n.file_count for n in selected)
    total_bytes = sum(n.total_bytes for n in selected)
    total_dirs = sum(n.dir_count for n in selected)
    grand_avg = total_bytes / total_files if total_files else 0.0

    table.add_column("Directory", footer=f"[bold]TOTAL ({len(selected)})[/]", overflow="fold")
    table.add_column("Files", justify="right", footer=f"[bold]{human_count(total_files)}[/]")
    table.add_column("Subdirs", justify="right", footer=f"[bold]{human_count(total_dirs)}[/]")
    table.add_column("Total size", justify="right", footer=f"[bold]{human_size(total_bytes)}[/]")
    table.add_column("Avg size", justify="right", footer=f"[bold]{human_size(grand_avg)}[/]")
    for n in selected:
        table.add_row(
            _display_name(n.path, root),
            human_count(n.file_count),
            human_count(n.dir_count),
            human_size(n.total_bytes),
            human_size(n.avg_bytes),
        )
    console.print(table)


# --------------------------------------------------------------------------- #
# Archive mode
# --------------------------------------------------------------------------- #


@dataclass(slots=True)
class ManifestEntry:
    """The contract linking one source path to one archive member.

    ``size``/``mtime_ns`` are captured at archive time so the delete stage can
    detect a file that changed after we read it and refuse to remove it.

    Directories get entries too (``is_dir``, arcname with a trailing ``/``).
    Without them an empty directory would have no archive representation at all,
    yet the delete stage still prunes it -- structure destroyed with no copy.

    ``external_attr`` is the permission/attribute word as it is stored in the
    archive, so verification can confirm the archive really carries what we
    recorded. See ``_external_attr`` for the layout.
    """

    src: str  # absolute source path
    arcname: str  # member name inside the archive ("/"-separated; dirs end in "/")
    size: int
    mtime_ns: int
    is_dir: bool = False
    external_attr: int = 0


@dataclass(slots=True)
class FolderResult:
    """Outcome for one top-level folder; drives the final summary table."""

    name: str
    status: str = "pending"  # ok | skipped | failed | cancelled | dry-run
    archived_files: int = 0
    archived_dirs: int = 0
    archived_bytes: int = 0
    deleted_files: int = 0
    undeleted: list[str] = field(default_factory=list)
    skipped_symlinks: int = 0
    message: str = ""


#: DOS attribute bits worth carrying. Deliberately excludes ARCHIVE (a backup
#: marker that says nothing about the file) and DIRECTORY (set from is_dir).
_DOS_ATTR_BITS = (
    getattr(stat, "FILE_ATTRIBUTE_READONLY", 0x01)
    | getattr(stat, "FILE_ATTRIBUTE_HIDDEN", 0x02)
    | getattr(stat, "FILE_ATTRIBUTE_SYSTEM", 0x04)
)
_DOS_DIRECTORY = 0x10
_DOS_READONLY = 0x01


def _external_attr(st: os.stat_result, is_dir: bool) -> int:
    """Build a zip ``external_attr`` word preserving both attribute models.

    A zip's 32-bit attribute word carries two independent things, and portable
    writers (Info-ZIP, 7-Zip) populate both -- so we do too:

    * high 16 bits -- the Unix mode (``0o100644``, ``0o40755``, ...).
    * low 8 bits -- the MS-DOS attribute byte (read-only / hidden / system /
      directory).

    Which half an extractor believes depends on ``create_system``, which zipfile
    sets from the *writing* platform: archives written on Windows are tagged
    MS-DOS, and Info-ZIP then derives modes from the DOS byte, ignoring the Unix
    half entirely. That is precisely why filling only the Unix half is not
    enough -- on Windows-written archives it is the half nobody reads.

    Python's ``ZipInfo.from_file`` fills in only the Unix half. On Windows that
    half is synthesised by CPython from the real attributes, so hidden and
    system were being dropped entirely -- and since this tool then deletes the
    source, dropped meant gone. Filling both halves keeps the archive faithful
    on whichever platform eventually reads it.
    """
    attr = (stat.S_IMODE(st.st_mode) | (stat.S_IFDIR if is_dir else stat.S_IFREG)) << 16
    dos = getattr(st, "st_file_attributes", None)
    if dos is not None:  # Windows: use the real attribute bits
        attr |= dos & _DOS_ATTR_BITS
    elif not st.st_mode & stat.S_IWUSR:  # POSIX: mirror unwritable as read-only
        attr |= _DOS_READONLY
    if is_dir:
        attr |= _DOS_DIRECTORY
    return attr


def _count_entries(entries: Sequence[ManifestEntry], result: FolderResult) -> None:
    """Record file/dir/byte totals. Directory members are counted separately so
    the reported file count stays comparable with ``--list`` output."""
    result.archived_files = sum(1 for e in entries if not e.is_dir)
    result.archived_dirs = sum(1 for e in entries if e.is_dir)
    result.archived_bytes = sum(e.size for e in entries)


def _arcname_candidates(arcname: str) -> Iterator[str]:
    """Yield *arcname*, then ``name__dup1.ext``, ``name__dup2.ext``, ... forever.

    The single source of truth for collision naming: both the "where can I write
    this?" and the "is it already here?" questions walk this same sequence, so
    they cannot drift apart.

    Only the BASENAME is split. Splitting the whole arcname would treat a dot in
    a directory component ("v1.2/data", "pkg/.bin/tool") as the extension
    separator and rewrite the directory path, silently relocating the file
    inside the archive. Arcnames always use "/" regardless of platform, and a
    directory's trailing "/" is preserved so it stays a directory member.
    """
    yield arcname
    body = arcname[:-1] if arcname.endswith("/") else arcname
    trailer = "/" if arcname.endswith("/") else ""
    head, sep, tail = body.rpartition("/")
    stem, suffix = os.path.splitext(tail)
    i = 1
    while True:
        yield f"{head}{sep}{stem}__dup{i}{suffix}{trailer}"
        i += 1


def _find_or_place(
    entry: ManifestEntry, index: dict[str, tuple[int, int, int]]
) -> tuple[str, int | None]:
    """Decide where *entry* belongs in the archive.

    Returns ``(arcname, stored_attr)``. A non-None *stored_attr* means the
    archive already holds this exact content under *arcname*, so it must not be
    written again; the value is the attribute word actually stored there, which
    is what the manifest records (see ``_archive_folder``).

    Crucially this walks the *whole* ``__dupN`` sequence rather than checking
    only the exact name. Checking just the exact name meant a source that had
    been renamed on an earlier run was never recognised again, so every
    subsequent run appended another byte-identical copy and the archive grew
    without bound.

    Content is compared by size *and* CRC32; a same-size edit must never be
    mistaken for the archived copy (see ``_archive_folder`` for why).
    """
    crc: int | None = None
    for candidate in _arcname_candidates(entry.arcname):
        prior = index.get(candidate)
        if prior is None:
            return candidate, None  # free slot: write here
        if entry.is_dir:
            return candidate, prior[2]  # directories carry no content to compare
        if prior[0] == entry.size:
            if crc is None:
                crc = _file_crc32(entry.src)
            if prior[1] == crc:
                return candidate, prior[2]  # byte-identical: already archived
    raise AssertionError("unreachable: _arcname_candidates is infinite")


#: Zip's DOS timestamp cannot express anything before 1980-01-01.
_DOS_EPOCH = (1980, 1, 1, 0, 0, 0)


def _dos_date_time(mtime_ns: int) -> tuple[int, int, int, int, int, int]:
    """Convert an mtime to zip's DOS timestamp, clamped to what zip can express.

    Zip refuses to write a header dated before 1980 at all. Clamping rather than
    letting that ValueError escape is deliberate: a file with a 1970 mtime --
    restored from an old archive, or written with a broken clock -- would
    otherwise be *permanently* unarchivable, so its folder could never be
    reclaimed no matter how often you re-ran. Losing a stored timestamp is a far
    smaller cost than a folder that can never be processed.

    The stored time is approximate regardless (2-second DOS resolution). This
    tool's own change detection reads ``st_mtime_ns`` from disk and never
    consults this value, so clamping cannot weaken the safety invariant.
    """
    try:
        parts = time.localtime(mtime_ns / 1e9)[:6]
    except (OSError, OverflowError, ValueError):  # nonsense mtime on disk
        return _DOS_EPOCH
    return _DOS_EPOCH if parts[0] < 1980 else parts


def _zipinfo_for(entry: ManifestEntry, compression: int, level: int | None) -> zipfile.ZipInfo:
    """Build the archive member header for *entry*.

    Built explicitly rather than via ``ZipInfo.from_file`` for two reasons: the
    timestamp needs clamping (above), and the full attribute word must be
    carried -- ``from_file`` fills only the Unix half and drops the DOS bits
    entirely (see ``_external_attr``).
    """
    info = zipfile.ZipInfo(entry.arcname, _dos_date_time(entry.mtime_ns))
    info.external_attr = entry.external_attr
    info.file_size = entry.size
    # A directory member holds no bytes; compressing it is pure overhead.
    info.compress_type = zipfile.ZIP_STORED if entry.is_dir else compression
    info._compresslevel = None if entry.is_dir else level
    return info


def _file_crc32(path: str) -> int:
    """Stream *path* and return its CRC32, in the same form ``ZipInfo.CRC`` uses."""
    crc = 0
    with open(path, "rb") as f:
        while True:
            _check_cancel()
            buf = f.read(CHUNK_SIZE)
            if not buf:
                return crc
            crc = zlib.crc32(buf, crc)


def _archive_folder(
    folder: Path,
    dest_zip: Path,
    partial: Path,
    entries: list[ManifestEntry],
    compression: int,
    level: int | None,
    progress: Progress,
    task_id,
    label: str | None = None,
) -> tuple[list[ManifestEntry], list[str]]:
    """Build *partial* containing every entry.

    Returns ``(written, failures)``. *written* is the manifest of entries proven
    to be in the archive; *failures* names sources that could not be read (a
    file vanished or got locked between enumeration and write). A non-empty
    *failures* list blocks deletion of the folder, exactly like a blocker from
    ``_entries_from_tree`` -- but the rest of the folder is still archived, so one
    locked file cannot waste the work of a million-file run.

    If *dest_zip* exists it is copied to *partial* first and appended to, so the
    existing archive is never mutated. The caller is responsible for verifying
    *partial* and only then swapping it into place. Failures here parallel the
    blockers ``_entries_from_tree`` reports at enumeration time.
    """
    # arcname -> (size, crc32, external_attr) for everything the archive holds.
    # Doubles as the set of taken names, so there is no second structure to
    # keep in sync.
    existing_by_name: dict[str, tuple[int, int, int]] = {}

    if dest_zip.exists():
        progress.update(
            task_id, description=f"{label or folder.name} [dim]copying existing zip[/]"
        )
        _copy_file(dest_zip, partial)
        with zipfile.ZipFile(partial, "r") as zf:
            for info in zf.infolist():
                existing_by_name[info.filename] = (info.file_size, info.CRC, info.external_attr)
        mode = "a"
    else:
        mode = "w"

    written: list[ManifestEntry] = []
    failures: list[str] = []
    kwargs = {"compresslevel": level} if level is not None else {}
    with zipfile.ZipFile(partial, mode, compression=compression, allowZip64=True, **kwargs) as zf:
        for entry in entries:
            _check_cancel()
            try:
                # Skip a re-add ONLY when the archive already holds this exact
                # content. Matching on size alone is NOT sufficient: a file
                # edited in place to the same length would be judged "already
                # archived", and we would then delete the source while the
                # archive still held the OLD bytes -- silent data loss, and a
                # direct violation of this tool's one invariant.
                arcname, stored_attr = _find_or_place(entry, existing_by_name)
                if stored_attr is not None:
                    # Already present. Record the attributes actually stored --
                    # which may predate this run, or this version -- so the
                    # manifest describes the archive rather than the disk, and
                    # verification stays truthful.
                    if stored_attr != entry.external_attr:
                        log.debug(
                            "attrs differ for existing member %s: archive=0x%08x source=0x%08x",
                            arcname, stored_attr, entry.external_attr,
                        )
                    written.append(replace(entry, arcname=arcname, external_attr=stored_attr))
                    progress.advance(task_id, entry.size)
                    continue
                if arcname != entry.arcname:
                    log.warning(
                        "name collision in %s: storing %s as %s", dest_zip, entry.arcname, arcname
                    )
                    entry = replace(entry, arcname=arcname)
                if entry.is_dir:
                    zf.writestr(_zipinfo_for(entry, compression, level), b"")
                else:
                    with open(entry.src, "rb") as src:
                        # The manifest entry may be as old as the pre-scan.
                        # Re-check size/mtime on the open handle (fstat is
                        # nearly free) and record what the file holds NOW, so
                        # verification and the pre-delete re-stat judge the
                        # bytes actually stored -- a source that changed since
                        # the scan is archived fresh instead of failing the
                        # whole folder's verification with a size mismatch.
                        # Attributes stay as scanned: metadata, not the
                        # guarantee.
                        st = os.fstat(src.fileno())
                        if st.st_size != entry.size or st.st_mtime_ns != entry.mtime_ns:
                            log.debug("changed since scan, archiving current bytes: %s", entry.src)
                            entry = replace(entry, size=st.st_size, mtime_ns=st.st_mtime_ns)
                        with zf.open(_zipinfo_for(entry, compression, level), "w") as dest:
                            shutil.copyfileobj(src, dest, CHUNK_SIZE)
                # Keep the index current: a later source file may legitimately
                # be named "f__dup1.txt" and must not silently overwrite the
                # slot we just allocated for a renamed "f.txt". zipfile appends
                # the ZipInfo when the member closes, so this is the one we
                # just wrote -- and its CRC is now populated.
                written_info = zf.infolist()[-1]
                existing_by_name[entry.arcname] = (
                    written_info.file_size, written_info.CRC, entry.external_attr
                )
            except (OSError, ValueError, RuntimeError) as exc:
                # One unusable source must not cost the folder its whole run:
                # record it as a blocker, keep archiving the rest, keep the
                # folder. RuntimeError covers a file that grows past the Zip64
                # boundary between stat and write, which zipfile reports only
                # when the member closes.
                # If the read died *mid-member*, zipfile still closes out the
                # truncated member, so the archive may hold a short copy under
                # this name. That is harmless: the entry never enters the
                # manifest, so it is neither verified nor deleted, and the intact
                # source stays on disk. A later run sees the CRC differ and
                # stores the good copy alongside it.
                failures.append(f"could not archive {entry.src}: {exc}")
                log.warning("unreadable source %s: %s", entry.src, exc)
                progress.advance(task_id, entry.size)
                continue
            written.append(entry)
            progress.advance(task_id, entry.size)
    # NOTE: the fsync MUST happen out here, after ZipFile.close() has run.
    # zipfile writes the central directory during close(), and without that
    # structure the archive is unreadable no matter how much file data survived.
    # Syncing inside the `with` block would durably persist the member bytes but
    # leave the central directory in the page cache -- a power loss after we
    # published and deleted would then yield a corrupt archive with no sources.
    _fsync_file(partial)
    return written, failures


def _fsync_file(path: Path) -> None:
    """Force *path*'s contents to stable storage.

    Opened O_RDWR because Windows' ``_commit`` (what ``os.fsync`` maps to there)
    requires a writable handle.
    """
    fd = os.open(path, os.O_RDWR)
    try:
        os.fsync(fd)
    finally:
        os.close(fd)


def _fsync_parent_dir(path: Path) -> None:
    """Best-effort: make *path*'s directory entry durable after a rename.

    On POSIX, ``os.replace`` is atomic but the rename itself is only guaranteed
    durable once the parent directory is synced; without this a crash could
    revert the publish step. Not applicable on Windows (directories cannot be
    opened for fsync), where the rename is journalled by NTFS -- hence the
    broad exception guard rather than a platform check.
    """
    try:
        fd = os.open(path.parent, os.O_RDONLY)
        try:
            os.fsync(fd)
        finally:
            os.close(fd)
    except OSError:
        pass  # unsupported on this platform/filesystem; the rename still applied


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
                if entry.is_dir and not info.is_dir():
                    problems.append(f"not stored as a directory: {entry.arcname}")
                    continue
                # Content first: it is the actual guarantee. An attribute
                # mismatch must never short-circuit this check, or a metadata
                # nit would mask real corruption.
                if full and not entry.is_dir:
                    try:
                        with zf.open(info, "r") as member:
                            while member.read(CHUNK_SIZE):
                                pass  # CRC checked by zipfile on EOF
                    except (zipfile.BadZipFile, OSError) as exc:
                        problems.append(f"unreadable member {entry.arcname}: {exc}")
                        continue
                # We promise to retain attributes, so we confirm them before
                # letting the source be deleted -- an unverified promise is not
                # one this tool is allowed to make.
                if info.external_attr != entry.external_attr:
                    problems.append(
                        f"attribute mismatch for {entry.arcname}: "
                        f"archive=0x{info.external_attr:08x} "
                        f"expected=0x{entry.external_attr:08x}"
                    )
                    continue
                if full:
                    # The bar's total budgets a verify pass only in full mode
                    # (see verify_factor in process_folder); advancing here in
                    # fast mode would overrun the total.
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


def _discard_partial(partial: Path) -> None:
    """Drop an incomplete archive. Never raises.

    A ``.partial`` is by definition not authoritative, so failing to remove one
    is cosmetic: the source data is intact either way and the next run replaces
    it. Losing the real error here would be worse than the leftover file, so it
    is logged.
    """
    try:
        if partial.exists():
            _force_remove(str(partial))
    except OSError as exc:
        log.warning("could not remove partial %s: %s", partial, exc)


def _delete_sources(folder: Path, manifest: Sequence[ManifestEntry], result: FolderResult) -> None:
    """Delete exactly the verified files, then prune the emptied directories.

    Each file is re-stat'ed right before removal: if it changed since archiving
    we keep it, because the archive no longer represents its current contents.
    """
    for entry in manifest:
        _check_cancel()
        if entry.is_dir:
            # Directories are not unlinked here: they are pruned bottom-up
            # below, and only if empty. Passing one to os.remove would fail and
            # be misreported as an undeletable path.
            continue
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

    # Prune directories bottom-up from the MANIFEST -- never os.walk, which
    # descends into junctions (it does not treat them as links either) and would
    # happily rmdir its way outside the folder we were asked to process.
    # Deepest first so children go before parents. Any directory still holding
    # something -- a kept file, a blocker, a file created during the run -- just
    # fails rmdir and stays, which is the outcome we want.
    for dirpath in sorted(
        (e.src for e in manifest if e.is_dir),
        key=lambda p: p.count(os.sep),
        reverse=True,
    ):
        try:
            os.rmdir(dirpath)
        except OSError as exc:
            log.debug("could not rmdir %s: %s", dirpath, exc)
    try:
        os.rmdir(folder)
    except OSError as exc:
        result.undeleted.append(f"{folder}: {exc}")
        log.debug("could not rmdir %s: %s", folder, exc)


def process_folder(
    folder: Path,
    args: argparse.Namespace,
    compression: int,
    level: int | None,
    progress: Progress,
    label: str | None = None,
    cached: DirNode | None = None,
) -> FolderResult:
    """Zip -> verify -> delete a single folder. Never raises.

    The archive is always written next to *folder* (``<parent>/<name>.zip``),
    so the partial and the final zip share a volume and ``os.replace`` stays
    atomic. *label* is the name shown in progress lines and the summary;
    callers pass a root-relative path when *folder* is nested (``--small``).
    *cached* is *folder*'s pre-scanned tree: when given, the enumeration is
    replayed from RAM instead of re-walking the disk; when omitted (tests,
    embedding) the folder is scanned here and now.
    """
    label = label or folder.name
    result = FolderResult(name=label)
    dest_zip = folder.parent / f"{folder.name}.zip"
    partial = folder.parent / f"{folder.name}{PARTIAL_SUFFIX}"
    task_id = None
    started = time.monotonic()

    # Everything lives inside the try, including setting up the progress task:
    # this function promises never to raise, and run_delete relies on it. A
    # leak here would abort the whole run and discard the results of folders
    # that had already finished.
    try:
        task_id = progress.add_task(f"{label} [dim]scanning[/]", total=None, start=True)
        log.info("=== BEGIN folder=%s archive=%s ===", folder, dest_zip)
        if dest_zip.exists() and args.exists:
            result.status = "skipped"
            result.message = "archive exists (--exists)"
            log.warning("SKIP %s: archive already exists and --exists is set", folder)
            return result

        entries, blockers = _entries_from_tree(
            cached if cached is not None else _scan_dir_tree(folder), result
        )
        _count_entries(entries, result)
        log.info(
            "folder=%s files=%d dirs=%d bytes=%d blockers=%d",
            folder, result.archived_files, result.archived_dirs,
            result.archived_bytes, len(blockers),
        )
        for b in blockers[:50]:
            log.warning("blocker in %s: %s", folder, b)

        # Dry-run exits before any write or unlink. Keep this check ahead of the
        # empty-folder branch below, which does remove directories.
        if args.dry_run:
            result.status = "dry-run"
            result.message = (
                "empty folder, would remove" if not entries and not blockers
                else f"would archive {result.archived_files} files"
                     + (f" + {result.archived_dirs} dirs" if result.archived_dirs else "")
            )
            return result

        if not entries and not blockers:
            # Empty tree: nothing to archive, so there is nothing to lose --
            # safe to remove the (possibly nested) empty directories.
            if args.keep:
                # --keep promises nothing is deleted. "It was only an empty
                # folder" is not an exception the user agreed to.
                result.status = "ok"
                result.message = "empty folder (--keep, folder retained)"
                return result
            _delete_sources(folder, [], result)
            result.status = "ok" if not result.undeleted else "failed"
            result.message = "empty folder removed" if not result.undeleted else "could not remove"
            return result

        if not entries:
            # Blockers only. Archiving would publish an empty zip next to a
            # folder we are keeping regardless -- clutter that also misreads as
            # "this folder was archived" when nothing was.
            result.status = "skipped"
            result.message = f"nothing archivable ({len(blockers)} unarchivable paths)"
            log.warning("KEEP %s: nothing archivable, %d blocker(s)", folder, len(blockers))
            return result

        # ---- 1. ARCHIVE (into the side file) --------------------------------
        # Total = bytes to write + bytes to verify, so one bar covers both.
        verify_factor = 2 if args.verify == "full" else 1
        progress.update(
            task_id,
            total=result.archived_bytes * verify_factor or 1,
            description=f"{label} [cyan]archiving[/]",
        )
        if partial.exists():
            log.warning("removing stale partial %s", partial)
            _discard_partial(partial)
        manifest, write_failures = _archive_folder(
            folder, dest_zip, partial, entries, compression, level, progress, task_id, label
        )
        if write_failures:
            # Sources we could not read are blockers too: the archive is still
            # good for everything else, but the folder must survive.
            blockers.extend(write_failures)
            entries_bytes = result.archived_bytes
            _count_entries(manifest, result)
            for f in write_failures[:50]:
                log.warning("archive failure in %s: %s", folder, f)
            if args.verify == "full":
                # The total budgeted a verify pass for every enumerated byte,
                # but only manifest bytes get verified; shrink it so the bar
                # can actually complete.
                progress.update(
                    task_id, total=(entries_bytes + result.archived_bytes) or 1
                )
        if not manifest:
            # Every entry failed at write time. Publishing would leave an empty
            # (or unchanged) archive that reads as "this folder was archived" --
            # and under --exists would then block the folder forever. Mirrors
            # the blockers-only guard above, which covers collect-time failures.
            result.status = "skipped"
            result.message = f"nothing archived ({len(blockers)} unarchivable paths)"
            log.warning("KEEP %s: nothing archived, %d blocker(s)", folder, len(blockers))
            _discard_partial(partial)
            return result

        # ---- 2. VERIFY (re-read from disk) ----------------------------------
        progress.update(task_id, description=f"{label} [magenta]verifying[/]")
        problems = _verify_archive(partial, manifest, args.verify == "full", progress, task_id)
        if problems:
            result.status = "failed"
            result.message = f"verification failed ({len(problems)} problems)"
            for p in problems[:50]:
                log.error("verify %s: %s", folder, p)
            log.error("ABORT %s: source folder left untouched", folder)
            _discard_partial(partial)  # worthless; the source is intact
            return result

        # ---- 3. PUBLISH (atomic swap; only now is the archive authoritative)
        os.replace(partial, dest_zip)
        _fsync_parent_dir(dest_zip)  # make the rename itself durable (POSIX)
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
        progress.update(task_id, description=f"{label} [red]deleting[/]")
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
        _discard_partial(partial)
        log.warning("CANCELLED folder=%s", folder)
        return result
    except Exception as exc:  # noqa: BLE001 - one bad folder must not kill the run
        result.status = "failed"
        result.message = str(exc)
        log.exception("UNEXPECTED failure on %s", folder)
        _discard_partial(partial)
        return result
    finally:
        log.info("=== END folder=%s status=%s %s ===", folder, result.status, result.message)
        if cached is not None:
            # Release this folder's enumeration cache: on long runs, memory
            # then tracks the folders still in flight rather than everything
            # already processed.
            cached.files.clear()
            cached.children.clear()
            cached.blockers.clear()
        if task_id is not None:
            try:
                progress.remove_task(task_id)
            except Exception:  # noqa: BLE001 - cosmetic teardown, never fatal
                log.debug("could not remove progress task for %s", folder, exc_info=True)


def run_delete(
    root: Path,
    dirs: Sequence[Path],
    args: argparse.Namespace,
    cache: dict[Path, DirNode] | None = None,
) -> list[FolderResult]:
    """Process *dirs* concurrently. With --small they may be nested under *root*,
    which is used only to shorten the names shown to the user. *cache* maps a
    folder to its pre-scanned tree so enumeration is not repeated on disk."""
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
                pool.submit(
                    process_folder, d, args, compression, level, progress,
                    _display_name(d, root), (cache or {}).get(d),
                ): d
                for d in dirs
            }
            try:
                for fut in as_completed(futures):
                    try:
                        res = fut.result()  # process_folder promises not to raise
                    except Exception as exc:  # noqa: BLE001 - belt and braces
                        # Should be unreachable. If it ever happens, losing one
                        # folder's *report* is survivable; losing the whole
                        # run's results is not. Nothing was deleted, because
                        # deletion only follows a successful verify.
                        folder = futures[fut]
                        log.exception("UNEXPECTED escape from process_folder %s", folder)
                        res = FolderResult(
                            name=_display_name(folder, root), status="failed",
                            message=f"internal error: {exc}",
                        )
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
    """Attach log handlers. Safe to call more than once.

    Raises ``OSError`` if *log_path* cannot be opened; the caller decides
    whether that is fatal.
    """
    # Drop any handlers from a previous call. Without this a second invocation
    # (tests, or an embedder calling main() twice) stacks another FileHandler on
    # top: every line gets logged twice, and the old file handle leaks.
    for handler in list(log.handlers):
        log.removeHandler(handler)
        handler.close()

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
            "  small2zip.py -s D:/data --dry-run  # preview which dirs --small would pick\n"
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
        "-e", "--exists", action="store_true",
        help="With --delete: refuse to touch a folder whose .zip already exists "
             "(default is to append missing files into the existing archive). "
             "Formerly called --strict.",
    )
    p.add_argument(
        "-s", "--small", nargs="?", const=True, default=None, metavar="DIR",
        help="Archive+delete only directories dominated by small files. Give "
             "the target as -s DIR, or combine the bare flag with -d DIR; like "
             "-d, it never guesses a directory. A directory qualifies when its "
             "subtree holds at least --small-files files with an average size "
             "of at most --small-avg KiB. One that does not qualify is kept, "
             "but its sub-directories are examined recursively and qualifying "
             "subtrees at any depth are archived, each zip written next to its "
             "directory. Shows the selection table and asks for confirmation "
             "before touching anything; preview with --dry-run.",
    )
    p.add_argument(
        "-q", "--quiet", action="store_true",
        help="With --small: skip the pre-run selection table. The confirmation "
             "prompt (with totals) still appears unless -y is given. Not valid "
             "with --dry-run, whose entire output is that table.",
    )
    p.add_argument(
        "--small-files", type=int, default=SMALL_MIN_FILES_DEFAULT, metavar="N",
        help="Requires -s/--small: minimum file count in a qualifying subtree "
             "(default: %(default)s).",
    )
    p.add_argument(
        "--small-avg", type=int, default=SMALL_MAX_AVG_KIB_DEFAULT, metavar="KIB",
        help="Requires -s/--small: maximum average file size, in KiB, of a "
             "qualifying subtree (default: %(default)s).",
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
        help="Compression level: deflate 0-9, bzip2 1-9, zstd -7-22 (negative "
             "levels are zstd's fastest modes). No effect with 'store' or "
             "'lzma'. Default: library default.",
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
        "--include-hidden", action=argparse.BooleanOptionalAction, default=True,
        help="Process folders whose name starts with '.' (default: included; "
             "pass --no-include-hidden to skip them, both at the top level and "
             "as --small candidates).",
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


def confirm_destructive(root: Path, nodes: Sequence[DirNode], keep: bool = False) -> bool:
    total_files = sum(n.file_count for n in nodes)
    total_bytes = sum(n.total_bytes for n in nodes)
    if keep:
        # The prompt must not threaten a deletion --keep promises not to do.
        action = "[bold yellow]Each folder will be zipped; --keep is set, nothing will be deleted[/]"
        note = "[dim]Re-run without --keep to reclaim the space afterwards.[/]"
        title, border = "[bold yellow]Archive operation", "yellow"
    else:
        action = "[bold red]Each folder will be zipped and then PERMANENTLY DELETED[/]"
        note = "[dim]Files are removed only after the archive is written and verified.[/]"
        title, border = "[bold red]Destructive operation", "red"
    console.print(
        Panel(
            Group(
                f"[bold]Target:[/] {root}",
                f"[bold]Folders:[/] {len(nodes)}",
                f"[bold]Files:[/] {human_count(total_files)}  "
                f"[bold]Size:[/] {human_size(total_bytes)}",
                "",
                action,
                note,
            ),
            title=title,
            border_style=border,
        )
    )
    try:
        answer = console.input("Type [bold]yes[/] to proceed: ").strip().lower()
    except (EOFError, KeyboardInterrupt):
        return False
    return answer == "yes"


def main(argv: Sequence[str] | None = None) -> int:
    argv_list = list(argv) if argv is not None else sys.argv[1:]
    # Argparse hands a short option with an optional value its trailing
    # characters as that value, so the natural typo "-sq" (meant: -s -q)
    # would parse as --small targeting a directory literally named "q" -- a
    # destructive run aimed by a typo, and -y would remove the confirmation
    # that could catch it. Refuse every attached form; the spaced "-s DIR"
    # is unambiguous.
    for tok in argv_list:
        if tok.startswith("-s") and tok != "-s" and not tok.startswith("--"):
            console.print(
                f"[bold red]Ambiguous option[/] '{tok}': write the target as "
                "'-s DIR' (with a space), or separate the flags ('-s -q')."
            )
            return 2
    args = build_parser().parse_args(argv_list)
    _install_signal_handlers()

    log_path = None if args.no_log else Path(args.log_path).expanduser()
    try:
        setup_logging(log_path, args.verbose)
    except OSError as exc:
        # The log is the audit trail for a destructive run, so a bad --log path
        # is a configuration error worth stopping for -- not something to
        # silently continue without.
        console.print(f"[bold red]Cannot open log file[/] {log_path}: {exc}")
        console.print("[dim]Choose another path with --log FILE, or pass --no-log.[/]")
        return 2

    # -s carries three states: None (absent), True (bare flag, target from -d),
    # or a DIR string (standalone form).
    small_requested = args.small is not None
    small_dir = args.small if isinstance(args.small, str) else None

    if args.list_path is not None and small_requested:
        # List mode reports every folder, unfiltered; a selection filter on it
        # could only mislead.
        console.print("[bold red]-s/--small cannot be combined with -l/--list.[/]")
        return 2
    if small_dir is not None and args.delete_path is not None:
        if Path(small_dir).expanduser().resolve() != Path(args.delete_path).expanduser().resolve():
            console.print("[bold red]-s DIR and -d DIR disagree[/] -- give one target.")
            return 2
    if small_requested and small_dir is None and args.delete_path is None:
        # Like -d, a destructive mode never guesses its target.
        console.print(
            "[bold red]--small needs an explicit target:[/] use -s DIR, or -d DIR -s."
        )
        return 2
    for flag, value in (("-d/--delete", args.delete_path), ("-s/--small", small_dir)):
        if value is not None and not value.strip():
            # Path("").resolve() is the CWD: an unset shell variable
            # (`-d "$DIR"`) must not quietly aim a destructive run there.
            console.print(
                f"[bold red]{flag} got an empty directory[/] -- likely an "
                "unset shell variable. Refusing to guess a target."
            )
            return 2

    delete_mode = args.delete_path is not None or small_dir is not None
    raw_root = args.delete_path or small_dir or args.list_path or args.path or "."
    root = Path(raw_root).expanduser().resolve()

    if args.path is not None and (delete_mode or args.list_path is not None):
        # Silently ignoring the extra path would look like it had been processed.
        console.print(f"[bold red]Unexpected extra path:[/] {args.path}")
        return 2
    if not root.is_dir():
        console.print(f"[bold red]Not a directory:[/] {root}")
        return 2
    if args.workers < 1:
        console.print("[bold red]--workers must be >= 1[/]")
        return 2
    # A silently ignored selection flag would archive far more than the user
    # intended, so anything that cannot mean what they asked for is fatal.
    if small_requested:
        if args.small_files < 1:
            console.print("[bold red]--small-files must be >= 1[/]")
            return 2
        if args.small_avg < 1:
            console.print("[bold red]--small-avg must be >= 1[/] (KiB)")
            return 2
        if args.quiet and args.dry_run:
            console.print(
                "[bold red]-q and --dry-run conflict:[/] the selection table "
                "-q suppresses is the very report --dry-run exists to show."
            )
            return 2
    else:
        if (
            args.small_files != SMALL_MIN_FILES_DEFAULT
            or args.small_avg != SMALL_MAX_AVG_KIB_DEFAULT
        ):
            console.print("[bold red]--small-files/--small-avg require -s/--small.[/]")
            return 2
        if args.quiet:
            console.print("[bold red]-q/--quiet applies only to --small runs.[/]")
            return 2
    if delete_mode and args.sort != "name":
        console.print("[bold red]--sort applies only to list mode.[/]")
        return 2
    if args.level is not None:
        if not COMPRESSION_METHODS[args.compress][1]:
            console.print(f"[yellow]--level has no effect with --compress {args.compress}.[/]")
        else:
            low, high = LEVEL_RANGES[args.compress]
            if not low <= args.level <= high:
                console.print(
                    f"[bold red]--level for {args.compress} must be "
                    f"{low}..{high}[/] (got {args.level})"
                )
                return 2

    # Log the argv actually parsed: when main() is called with an explicit argv
    # (tests, embedding), sys.argv describes the host process, not this run.
    log.info("start argv=%s root=%s mode=%s", argv_list, root, "delete" if delete_mode else "list")

    try:
        dirs = iter_top_level_dirs(root, args.include_hidden)
    except OSError as exc:  # unreadable root, or it vanished after the is_dir check
        console.print(f"[bold red]Cannot read[/] {root}: {exc}")
        return 2
    if not dirs:
        console.print(f"[yellow]No first-level folders found in[/] {root}")
        return 0

    if not delete_mode:
        # collect=False: a listing needs counters, not the enumeration cache,
        # so even a huge volume costs no meaningful RAM.
        nodes = scan_dir_trees(dirs, args.workers, collect=False)
        if cancel_event.is_set():
            console.print("[yellow]Cancelled during scan.[/]")
            return 130
        render_list(nodes, root, args.sort)
        return 0

    # Delete mode always starts with the tree scan: it powers the --small
    # selection and the confirmation summary (the user always sees the blast
    # radius before agreeing), and its cached enumeration is what the archive
    # stage replays -- the disk is walked exactly once.
    roots = scan_dir_trees(dirs, args.workers)
    if cancel_event.is_set():
        console.print("[yellow]Cancelled during scan.[/]")
        return 130

    if small_requested:
        nodes, blocked = select_small_dirs(
            roots, args.small_files, args.small_avg * 1024, args.include_hidden
        )
        roots.clear()  # unselected trees (and their enumeration) are no longer needed
        if args.exists:
            # Prune up front what process_folder would skip anyway, so the
            # --dry-run table matches exactly what a real run will do.
            remaining = []
            skipped_existing = 0
            for n in nodes:
                if (n.path.parent / f"{n.path.name}.zip").exists():
                    skipped_existing += 1
                else:
                    remaining.append(n)
            nodes = remaining
            if skipped_existing:
                console.print(
                    f"[yellow]--exists: {skipped_existing} selected "
                    f"{'directory' if skipped_existing == 1 else 'directories'} "
                    "skipped -- archive already exists.[/]"
                )
        if blocked:
            noun, verb = ("directory", "contains") if blocked == 1 else ("directories", "contain")
            console.print(
                f"[yellow]{blocked} {noun} met the size criteria but {verb} "
                "unarchivable paths (symlinks, junctions or unreadable files); "
                "only clean qualifying sub-directories were selected.[/]"
            )
        if not args.quiet or not nodes:
            # -q skips the table, never the "nothing to do" outcome. The
            # confirmation prompt below still shows the totals either way.
            render_small_selection(
                root, nodes, args.small_files, args.small_avg * 1024,
                args.dry_run, args.keep,
            )
        if not nodes or args.dry_run:
            # The table above IS the dry-run report; nothing was touched.
            return 0
    else:
        nodes = roots

    if not (args.yes or args.dry_run) and not confirm_destructive(root, nodes, args.keep):
        console.print("[yellow]Aborted -- nothing was changed.[/]")
        return 1

    results = run_delete(
        root, [n.path for n in nodes], args, {n.path: n for n in nodes}
    )
    return render_summary(results, log_path)


if __name__ == "__main__":
    sys.exit(main())
