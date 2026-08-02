#!/usr/bin/env python3
"""Summarize Git repositories in the immediate subdirectories of a path."""

from __future__ import annotations

import argparse
import locale
import os
import shutil
import signal
import subprocess
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import List, Optional, Sequence, Tuple

try:
    from rich.console import Console
    from rich.markup import escape
    from rich.panel import Panel
    from rich.progress import (
        BarColumn,
        MofNCompleteColumn,
        Progress,
        SpinnerColumn,
        TextColumn,
        TimeElapsedColumn,
    )
    from rich.table import Table

    RICH_AVAILABLE = True
except ImportError:  # The utility remains useful before pcprep installs Rich.
    RICH_AVAILABLE = False


@dataclass
class CommandResult:
    returncode: int
    stdout: bytes
    stderr: bytes
    timed_out: bool = False


@dataclass
class FolderStatus:
    name: str
    path: Path
    kind: str = "non-repository"
    branch: str = ""
    staged: int = 0
    unstaged: int = 0
    untracked: int = 0
    conflicts: int = 0
    remotes: List[str] = field(default_factory=list)
    upstream: str = ""
    ahead: Optional[int] = None
    behind: Optional[int] = None
    notes: List[str] = field(default_factory=list)
    error: str = ""

    @property
    def dirty(self) -> bool:
        return any((self.staged, self.unstaged, self.untracked, self.conflicts))

    @property
    def non_primary_branch(self) -> bool:
        """Whether this worktree is on a named branch other than main/master."""
        return (
            self.kind == "worktree"
            and bool(self.branch)
            and self.branch not in ("main", "master", "unborn")
            and not self.branch.startswith("detached@")
        )


def _decode(data: bytes) -> str:
    encoding = locale.getpreferredencoding(False) or "utf-8"
    return data.decode(encoding, errors="replace")


def _stop_process(process: subprocess.Popen[bytes]) -> None:
    """Stop a Git process group, escalating only if it does not exit."""
    if process.poll() is not None:
        return
    if os.name == "nt":
        try:
            process.send_signal(signal.CTRL_BREAK_EVENT)
            process.wait(timeout=1.5)
            return
        except (OSError, subprocess.TimeoutExpired):
            pass
    else:
        try:
            os.killpg(process.pid, signal.SIGTERM)
            process.wait(timeout=1.5)
            return
        except (OSError, subprocess.TimeoutExpired):
            pass
    try:
        process.terminate()
        process.wait(timeout=1.5)
    except (OSError, subprocess.TimeoutExpired):
        try:
            process.kill()
            process.wait(timeout=1.5)
        except (OSError, subprocess.TimeoutExpired):
            pass


def _run(command: Sequence[str], cwd: Path, timeout: float) -> CommandResult:
    creationflags = 0
    start_new_session = False
    if os.name == "nt":
        creationflags = getattr(subprocess, "CREATE_NEW_PROCESS_GROUP", 0)
    else:
        start_new_session = True

    environment = os.environ.copy()
    environment.setdefault("GIT_TERMINAL_PROMPT", "0")
    process = subprocess.Popen(
        list(command),
        cwd=str(cwd),
        stdin=subprocess.DEVNULL,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        env=environment,
        creationflags=creationflags,
        start_new_session=start_new_session,
    )
    try:
        stdout, stderr = process.communicate(timeout=timeout)
    except subprocess.TimeoutExpired:
        _stop_process(process)
        stdout, stderr = process.communicate()
        return CommandResult(process.returncode or 1, stdout, stderr, timed_out=True)
    except KeyboardInterrupt:
        _stop_process(process)
        process.communicate()
        raise
    return CommandResult(process.returncode, stdout, stderr)


def _git(cwd: Path, arguments: Sequence[str], timeout: float) -> CommandResult:
    return _run(["git", "-c", "color.ui=false", *arguments], cwd, timeout)


def _one_line_error(result: CommandResult, timeout: float) -> str:
    if result.timed_out:
        return f"Git command timed out after {timeout:g}s"
    message = _decode(result.stderr).strip() or _decode(result.stdout).strip()
    if not message:
        return f"Git exited with code {result.returncode}"
    line = " ".join(message.splitlines())
    return line if len(line) <= 180 else line[:177] + "..."


def _same_path(left: Path, right_text: str) -> bool:
    try:
        right = Path(right_text.strip()).resolve(strict=False)
        left_resolved = left.resolve(strict=False)
    except OSError:
        return False
    return os.path.normcase(str(left_resolved)) == os.path.normcase(str(right))


def _repository_kind(folder: Path, timeout: float) -> str:
    # A .git directory or file is the cheapest and most exact root marker.
    try:
        if (folder / ".git").exists():
            return "worktree"
    except OSError:
        pass

    top = _git(folder, ["rev-parse", "--show-toplevel"], timeout)
    if top.returncode == 0 and _same_path(folder, _decode(top.stdout)):
        return "worktree"

    bare = _git(folder, ["rev-parse", "--is-bare-repository"], timeout)
    if bare.returncode == 0 and _decode(bare.stdout).strip() == "true":
        git_dir = _git(folder, ["rev-parse", "--absolute-git-dir"], timeout)
        if git_dir.returncode == 0 and _same_path(folder, _decode(git_dir.stdout)):
            return "bare"
    return "non-repository"


def _parse_porcelain(data: bytes) -> Tuple[int, int, int, int]:
    staged = unstaged = untracked = conflicts = 0
    entries = data.split(b"\0")
    index = 0
    conflict_codes = {b"DD", b"AU", b"UD", b"UA", b"DU", b"AA", b"UU"}

    while index < len(entries):
        entry = entries[index]
        index += 1
        if not entry:
            continue
        code = entry[:2]
        if code == b"??":
            untracked += 1
            continue
        if code in conflict_codes or b"U" in code:
            conflicts += 1
        else:
            if len(code) > 0 and code[0:1] not in (b" ", b"?"):
                staged += 1
            if len(code) > 1 and code[1:2] not in (b" ", b"?"):
                unstaged += 1
        # In -z mode, copies and renames carry a second NUL-delimited path.
        if b"R" in code or b"C" in code:
            index += 1
    return staged, unstaged, untracked, conflicts


def _text(result: CommandResult) -> str:
    return _decode(result.stdout).strip()


def _git_config(folder: Path, key: str, timeout: float) -> str:
    result = _git(folder, ["config", "--get", key], timeout)
    return _text(result) if result.returncode == 0 else ""


def _current_branch(folder: Path, timeout: float) -> Tuple[str, bool]:
    symbolic = _git(folder, ["symbolic-ref", "--quiet", "--short", "HEAD"], timeout)
    if symbolic.returncode == 0:
        return _text(symbolic), False
    commit = _git(folder, ["rev-parse", "--verify", "--short", "HEAD"], timeout)
    if commit.returncode == 0:
        return f"detached@{_text(commit)}", True
    return "unborn", False


def _remote_names(folder: Path, timeout: float) -> List[str]:
    result = _git(folder, ["remote"], timeout)
    if result.returncode != 0:
        return []
    return sorted((line for line in _text(result).splitlines() if line), key=str.casefold)


def _fetch_remotes(status: FolderStatus, timeout: float) -> None:
    for remote in status.remotes:
        fetched = _git(
            cwd=status.path,
            arguments=["fetch", "--quiet", "--prune", remote],
            timeout=timeout,
        )
        if fetched.returncode != 0:
            status.notes.append(f"fetch {remote}: {_one_line_error(fetched, timeout)}")


def _configured_upstream(folder: Path, branch: str, timeout: float) -> str:
    remote = _git_config(folder, f"branch.{branch}.remote", timeout)
    merge = _git_config(folder, f"branch.{branch}.merge", timeout)
    if not remote or not merge:
        return ""
    branch_name = merge[len("refs/heads/") :] if merge.startswith("refs/heads/") else merge
    return branch_name if remote == "." else f"{remote}/{branch_name}"


def _analyze_worktree(folder: Path, timeout: float, fetch: bool) -> FolderStatus:
    status = FolderStatus(name=folder.name, path=folder, kind="worktree")
    status.branch, detached = _current_branch(folder, timeout)
    status.remotes = _remote_names(folder, timeout)
    if fetch:
        _fetch_remotes(status, timeout)

    porcelain = _git(
        folder,
        ["status", "--porcelain=v1", "-z", "--untracked-files=normal"],
        timeout,
    )
    if porcelain.returncode != 0:
        status.error = _one_line_error(porcelain, timeout)
        return status
    status.staged, status.unstaged, status.untracked, status.conflicts = _parse_porcelain(
        porcelain.stdout
    )

    if detached or status.branch == "unborn":
        return status

    upstream = _git(
        folder,
        ["rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{upstream}"],
        timeout,
    )
    if upstream.returncode == 0:
        status.upstream = _text(upstream)
    else:
        # Preserve a configured-but-missing upstream in the report.
        status.upstream = _configured_upstream(folder, status.branch, timeout)
        if not status.upstream:
            return status

    distance = _git(folder, ["rev-list", "--left-right", "--count", "HEAD...@{upstream}"], timeout)
    if distance.returncode != 0:
        status.notes.append(f"compare {status.upstream}: {_one_line_error(distance, timeout)}")
        return status
    fields = _text(distance).split()
    if len(fields) == 2 and all(value.isdigit() for value in fields):
        status.ahead, status.behind = int(fields[0]), int(fields[1])
    else:
        status.notes.append(f"compare {status.upstream}: unexpected Git output")
    return status


def _analyze_bare(folder: Path, timeout: float, fetch: bool) -> FolderStatus:
    status = FolderStatus(name=folder.name, path=folder, kind="bare", branch="bare")
    status.remotes = _remote_names(folder, timeout)
    if fetch:
        _fetch_remotes(status, timeout)
    return status


def _analyze(folder: Path, timeout: float, fetch: bool) -> FolderStatus:
    try:
        kind = _repository_kind(folder, timeout)
        if kind == "worktree":
            return _analyze_worktree(folder, timeout, fetch)
        if kind == "bare":
            return _analyze_bare(folder, timeout, fetch)
        return FolderStatus(name=folder.name, path=folder)
    except (OSError, subprocess.SubprocessError) as exc:
        return FolderStatus(name=folder.name, path=folder, kind="error", error=str(exc))


def _list_folders(root: Path) -> List[Path]:
    folders: List[Path] = []
    with os.scandir(root) as entries:
        for entry in entries:
            try:
                if entry.is_dir():
                    folders.append(Path(entry.path))
            except OSError:
                # Keep inaccessible directory entries visible in the result.
                folders.append(Path(entry.path))
    return sorted(folders, key=lambda item: item.name.casefold())


def _collect(
    folders: Sequence[Path],
    timeout: float,
    fetch: bool,
    use_rich: bool,
    show_progress: bool,
    no_color: bool,
) -> Tuple[List[FolderStatus], bool]:
    results: List[FolderStatus] = []
    cancelled = False

    if use_rich and show_progress:
        console = Console(no_color=no_color, highlight=False)
        progress = Progress(
            SpinnerColumn(),
            TextColumn("[bold cyan]{task.description}"),
            BarColumn(bar_width=None),
            MofNCompleteColumn(),
            TimeElapsedColumn(),
            console=console,
            transient=True,
        )
        try:
            with progress:
                task = progress.add_task("Scanning", total=len(folders))
                for folder in folders:
                    progress.update(task, description=f"Checking {escape(folder.name)}")
                    results.append(_analyze(folder, timeout, fetch))
                    progress.advance(task)
        except KeyboardInterrupt:
            cancelled = True
    else:
        try:
            for index, folder in enumerate(folders, start=1):
                if show_progress:
                    print(f"[{index}/{len(folders)}] Checking {folder.name}...", file=sys.stderr)
                results.append(_analyze(folder, timeout, fetch))
        except KeyboardInterrupt:
            cancelled = True
    return results, cancelled


def _working_tree_text(status: FolderStatus) -> str:
    if status.error:
        return "error"
    if status.kind == "non-repository":
        return "not a Git repository"
    if status.kind == "bare":
        return "bare repository"
    if not status.dirty:
        return "clean"
    parts = []
    if status.conflicts:
        parts.append(f"{status.conflicts} conflict{'s' if status.conflicts != 1 else ''}")
    if status.staged:
        parts.append(f"{status.staged} staged")
    if status.unstaged:
        parts.append(f"{status.unstaged} unstaged")
    if status.untracked:
        parts.append(f"{status.untracked} untracked")
    return ", ".join(parts)


def _upstream_text(status: FolderStatus) -> str:
    if status.upstream:
        return status.upstream
    if status.remotes:
        return "none (remotes: " + ", ".join(status.remotes) + ")"
    return "none"


def _sync_text(status: FolderStatus) -> str:
    if status.kind not in ("worktree",):
        return "-"
    if status.error:
        return "error"
    if status.branch.startswith("detached@"):
        return "detached HEAD"
    if status.branch == "unborn":
        return "no commits"
    if not status.upstream:
        return "no upstream"
    if status.ahead is None or status.behind is None:
        return "comparison unavailable"
    if status.ahead and status.behind:
        return f"diverged: ahead {status.ahead}, behind {status.behind}"
    if status.ahead:
        return f"ahead {status.ahead} (unpushed)"
    if status.behind:
        return f"behind {status.behind}"
    return "up to date"


def _summary(results: Sequence[FolderStatus]) -> str:
    repositories = [item for item in results if item.kind in ("worktree", "bare")]
    worktrees = [item for item in repositories if item.kind == "worktree" and not item.error]
    dirty = sum(item.dirty for item in worktrees)
    clean = len(worktrees) - dirty
    ahead = sum(bool(item.ahead) for item in worktrees)
    behind = sum(bool(item.behind) for item in worktrees)
    non_primary = sum(item.non_primary_branch for item in worktrees)
    errors = sum(bool(item.error or item.notes) or item.kind == "error" for item in results)
    non_repositories = sum(item.kind == "non-repository" for item in results)
    return (
        f"{len(repositories)} repositories  |  {clean} clean  |  {dirty} dirty  |  "
        f"{non_primary} non-main/master  |  {ahead} ahead  |  {behind} behind  |  "
        f"{errors} errors  |  "
        f"{non_repositories} non-repositories"
    )


def _rich_style_worktree(status: FolderStatus) -> str:
    text = escape(_working_tree_text(status))
    if status.error:
        return f"[bold red]{text}[/]"
    if status.kind == "worktree" and status.dirty:
        return f"[yellow]{text}[/]"
    if status.kind == "worktree":
        return f"[green]{text}[/]"
    return f"[dim]{text}[/]"


def _rich_style_branch(status: FolderStatus) -> str:
    text = escape(status.branch or "-")
    if status.non_primary_branch:
        return f"[bold yellow]⚑ {text}[/]"
    return text


def _rich_style_sync(status: FolderStatus) -> str:
    text = escape(_sync_text(status))
    if status.error or "unavailable" in text:
        return f"[red]{text}[/]"
    if status.ahead and status.behind:
        return f"[bold magenta]{text}[/]"
    if status.ahead:
        return f"[cyan]{text}[/]"
    if status.behind:
        return f"[yellow]{text}[/]"
    if text == "up to date":
        return f"[green]{text}[/]"
    return f"[dim]{text}[/]"


def _render_rich(
    root: Path, results: Sequence[FolderStatus], fetch: bool, cancelled: bool, no_color: bool
) -> None:
    console = Console(no_color=no_color, highlight=False)
    table = Table(
        title=f"Git repositories under {escape(str(root))}",
        header_style="bold white",
        border_style="bright_black",
        show_lines=False,
    )
    table.add_column("Folder", style="bold", no_wrap=True)
    table.add_column("Branch", no_wrap=True)
    table.add_column("Working tree")
    table.add_column("Upstream")
    table.add_column("Sync")
    table.add_column("Notes", overflow="fold")

    for status in results:
        notes = list(status.notes)
        if status.error:
            notes.insert(0, status.error)
        if status.non_primary_branch:
            notes.insert(0, "non-main/master branch")
        table.add_row(
            escape(status.name),
            _rich_style_branch(status),
            _rich_style_worktree(status),
            escape(_upstream_text(status)) if status.kind in ("worktree", "bare") else "[dim]-[/]",
            _rich_style_sync(status),
            "\n".join(escape(note) for note in notes),
        )

    fetch_failed = any(note.startswith("fetch ") for item in results for note in item.notes)
    if fetch and fetch_failed:
        table.caption = "Remote refs were refreshed where possible; fetch failures are listed in Notes."
    elif fetch:
        table.caption = "Remote-tracking refs were refreshed with --fetch."
    else:
        table.caption = "Remote comparison uses local tracking refs; pass --fetch for a live refresh."
    console.print(table)
    summary = _summary(results)
    if cancelled:
        summary += "\n[bold yellow]Cancelled: partial results shown.[/]"
    console.print(Panel(summary, title="Summary", border_style="cyan"))


def _render_plain(
    root: Path, results: Sequence[FolderStatus], fetch: bool, cancelled: bool
) -> None:
    print(f"Git repositories under {root}")
    headers = ("Folder", "Branch", "Working tree", "Upstream", "Sync", "Notes")
    rows = []
    for status in results:
        notes = list(status.notes)
        if status.error:
            notes.insert(0, status.error)
        if status.non_primary_branch:
            notes.insert(0, "non-main/master branch")
        rows.append(
            (
                status.name,
                status.branch or "-",
                _working_tree_text(status),
                _upstream_text(status) if status.kind in ("worktree", "bare") else "-",
                _sync_text(status),
                "; ".join(notes),
            )
        )
    widths = [len(value) for value in headers]
    for row in rows:
        for index, value in enumerate(row):
            widths[index] = min(50, max(widths[index], len(value)))
    print("  ".join(value.ljust(widths[index]) for index, value in enumerate(headers)))
    print("  ".join("-" * width for width in widths))
    for row in rows:
        values = [value if len(value) <= 50 else value[:47] + "..." for value in row]
        print("  ".join(value.ljust(widths[index]) for index, value in enumerate(values)))
    print()
    fetch_failed = any(note.startswith("fetch ") for item in results for note in item.notes)
    if fetch and fetch_failed:
        print("Remote refs were refreshed where possible; fetch failures are listed in Notes.")
    elif fetch:
        print("Remote-tracking refs were refreshed with --fetch.")
    else:
        print("Remote comparison uses local tracking refs; pass --fetch for a live refresh.")
    print(_summary(results))
    if cancelled:
        print("Cancelled: partial results shown.")


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="gitstatall",
        description=(
            "Show Git working-tree and upstream status for every immediate subdirectory. "
            "The scan is deliberately non-recursive."
        ),
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""examples:
  gitstatall
  gitstatall D:\\GitHubSrc
  gitstatall D:\\GitHubSrc --fetch
  gitstatall --no-progress --no-color

Ctrl+C stops the active Git command and prints the results collected so far.""",
    )
    parser.add_argument(
        "path",
        nargs="?",
        default=".",
        help="parent directory to scan (default: current directory)",
    )
    parser.add_argument(
        "--fetch",
        action="store_true",
        help="fetch and prune every remote before comparing the current branch",
    )
    parser.add_argument(
        "--timeout",
        type=float,
        default=60.0,
        metavar="SECONDS",
        help="maximum time for each Git command (default: 60)",
    )
    parser.add_argument(
        "--no-progress",
        action="store_true",
        help="disable the live progress display",
    )
    parser.add_argument(
        "--no-color",
        action="store_true",
        help="disable terminal colors",
    )
    return parser


def main(argv: Optional[Sequence[str]] = None) -> int:
    args = _parser().parse_args(argv)
    if args.timeout <= 0:
        print("ERROR: --timeout must be greater than zero.", file=sys.stderr)
        return 2
    if shutil.which("git") is None:
        print("ERROR: Git was not found on PATH.", file=sys.stderr)
        return 2

    try:
        root = Path(args.path).expanduser().resolve(strict=True)
    except (OSError, RuntimeError) as exc:
        print(f"ERROR: Cannot open scan path {args.path!r}: {exc}", file=sys.stderr)
        return 2
    if not root.is_dir():
        print(f"ERROR: Scan path is not a directory: {root}", file=sys.stderr)
        return 2

    try:
        folders = _list_folders(root)
    except OSError as exc:
        print(f"ERROR: Cannot list {root}: {exc}", file=sys.stderr)
        return 2

    use_rich = RICH_AVAILABLE
    if not RICH_AVAILABLE and not args.no_progress:
        print("Note: install 'rich' for colors, tables, and a live progress bar.", file=sys.stderr)
    results, cancelled = _collect(
        folders,
        args.timeout,
        args.fetch,
        use_rich,
        not args.no_progress,
        args.no_color,
    )
    if use_rich:
        _render_rich(root, results, args.fetch, cancelled, args.no_color)
    else:
        _render_plain(root, results, args.fetch, cancelled)
    if cancelled:
        return 130
    return 1 if any(item.error or item.notes or item.kind == "error" for item in results) else 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except KeyboardInterrupt:
        print("\nCancelled.", file=sys.stderr)
        raise SystemExit(130)
