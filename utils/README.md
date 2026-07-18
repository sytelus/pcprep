# small2zip

Inventory the first-level folders of a directory, and optionally **archive each
one into a zip and permanently delete the original folder** — with a hard
guarantee that no file is ever lost.

Typical use: a drive holding thousands of small project/dataset folders with
millions of tiny files. Small files waste enormous space in slack (a 3 KB file
still occupies a full cluster) and make backup/sync tools crawl. Collapsing each
folder into one zip reclaims space and turns millions of files into hundreds.

## Goals

1. **Never lose a file.** This is the only requirement that cannot be traded
   against speed, convenience or simplicity.
2. Be fast on directory trees with millions of small files.
3. Be interruptible at any moment, safely.
4. Leave an audit trail good enough to debug a bad run after the fact.

## Requirements

* Python 3.10+ (uses `X | Y` type unions and `dataclass(slots=True)`)
* [`rich`](https://github.com/Textualize/rich) for the tables and progress bars

```bash
pip install -r utils/requirements.txt
```

Standard library otherwise. Works on Windows, Linux and macOS. `-c zstd`
additionally requires Python 3.14+ and is hidden on older interpreters.

## Usage

```bash
# List mode (the default) — first-level folders with counts and sizes
python small2zip.py                       # current directory
python small2zip.py -l D:/data            # explicit directory
python small2zip.py D:/data --sort size   # positional form; sort by total size

# Destructive mode — zip each first-level folder, then delete it
python small2zip.py -d D:/data --dry-run  # preview, writes/deletes nothing
python small2zip.py -d D:/data            # prompts for confirmation
python small2zip.py -d D:/data -y -c store -w 12
```

`--delete` requires an explicit directory — it never defaults to the current
directory, because the cost of being wrong is unrecoverable.

### Options

| Option | Default | Purpose |
| --- | --- | --- |
| `-l`, `--list [DIR]` | `.` | List first-level folders (default mode). |
| `-d`, `--delete DIR` | — | Archive then delete each first-level folder. |
| `-s`, `--strict` | off | Skip any folder whose `.zip` already exists, instead of appending into it. |
| `-w`, `--workers N` | `min(8, cpus)` | Folders processed concurrently. |
| `-c`, `--compress` | `store` | `store` \| `deflate` \| `bzip2` \| `lzma` \| `zstd` (3.14+). Default does no compression; see [Performance](#performance). |
| `--level N` | library default | Compression level (deflate 0–9, bzip2 1–9, zstd −7–22). Validated up front; no effect with `store`/`lzma`. |
| `--verify {full,fast}` | `full` | `full` re-reads every member and validates CRCs before deleting. |
| `--keep` | off | Create and verify archives, but delete nothing — including empty folders. |
| `--dry-run` | off | Report what would happen; no writes, no deletes. |
| `-y`, `--yes` | off | Skip the confirmation prompt. |
| `--sort` | `name` | List-mode sort: `name` \| `size` \| `count` \| `avg`. |
| `--include-hidden` | off | Include dot-folders. |
| `--log FILE` | `~/small2zip.log` | Log destination. |
| `--no-log` | off | Disable file logging. |
| `-v`, `--verbose` | off | Debug logging (per-file detail), also echoed to console. |

### Exit codes

| Code | Meaning |
| --- | --- |
| `0` | Success. |
| `1` | At least one folder failed, or the user declined the prompt. Failed folders' source data was **not** deleted. |
| `2` | Bad arguments, target is not a directory, or the log file cannot be opened. |
| `130` | Cancelled by signal. |

## The safety model

The tool upholds one invariant:

> A file is removed from disk **only after** a readable archive on disk is proven
> to contain that exact file's bytes.

Each folder passes through four ordered stages. Deletion is stage 4 and is
unreachable unless stages 1–3 all succeeded.

```
1. ARCHIVE   write into <folder>.zip.partial  (never into the real .zip)
                └─ if a .zip already exists, it is COPIED to .partial first,
                   then appended to — the existing archive is never mutated
2. VERIFY    re-open .partial from disk; for every file we meant to store,
             confirm the member exists, its size matches, and (default) stream
             it so zipfile validates the stored CRC32
3. PUBLISH   os.replace(.partial, .zip)  — atomic; only now is it authoritative
4. DELETE    unlink exactly the verified files, one by one, each re-stat'ed
             immediately before removal; then prune the emptied directories
```

Key properties that follow:

* **A crash or `Ctrl+C` cannot lose data.** Only the `.partial` is ever in an
  inconsistent state, and it is discarded. The source folder is untouched until
  stage 4, and any pre-existing `.zip` survives intact. `SIGINT`, `SIGTERM` and
  (on Windows) `SIGBREAK` are all trapped so the run unwinds cleanly and exits
  `130`; a second interrupt exits immediately. Measured on a 20,000-file run
  interrupted mid-flight: 9,996 files archived, 10,004 left on disk, zero
  corrupted, zero unaccounted for, no `.partial` left behind.
* **The writer is never trusted.** Verification re-opens the file from disk;
  no in-memory state from stage 1 is reused. The archive is `fsync`ed before
  verification, so a "verified" archive really is on the platter.
* **Deletion is manifest-driven.** A *manifest entry* is the contract
  "this exact source file is inside that archive" — produced by stage 1,
  confirmed by stage 2, consumed by stage 4. There is no `rmtree`; only paths
  present in the verified manifest are ever unlinked.
* **Modified-since-archive files are kept.** Each file is re-`stat`ed right
  before unlink. If size or mtime moved since it was read, the archive no longer
  represents its current contents, so the file stays and is reported.
* **"Already archived" is proven by content.** When appending, a source is
  skipped only if the stored member matches it on size *and* CRC32, so a file
  edited in place can never be mistaken for its archived copy.
* **Nothing that points elsewhere is followed.** Symlinks and Windows junctions
  are refused, and the prune walks the manifest rather than `os.walk`, so the
  tool can never archive-then-delete files living outside the target folder.
* **Any doubt keeps the data.** Unreadable path, symlink, junction, verification
  miss, cancellation or a failed unlink all abort deletion for that folder. The
  worst case is a folder surviving next to a valid archive — recoverable by
  re-running. The reverse never happens.
* **One bad file does not discard the folder's work.** A source that vanishes or
  locks between enumeration and write is recorded as a blocker: everything else
  is still archived and published, and the folder is kept rather than deleted.

**If you modify this script, re-derive the invariant.** Any change that moves
work before verification, reuses writer state during verification, or widens
deletion beyond the manifest breaks the guarantee.

## What is retained

The source folder is deleted, so what the archive does not store is gone. What
survives:

| Item | Retained | Notes |
| --- | --- | --- |
| File contents | ✅ | CRC-verified before anything is deleted. |
| Directory structure | ✅ | Every sub-directory is stored as its own member. |
| **Empty directories** | ✅ | Stored explicitly; they would otherwise vanish. |
| Unix mode bits (`rwx`) | ✅ | High 16 bits of `external_attr`. |
| DOS read-only / hidden / system | ✅ | Low byte of `external_attr`. |
| Modification time | ⚠️ | 2-second resolution (zip's DOS timestamp). |
| Creation / access time | ❌ | Not stored. |
| Owner / group, ACLs | ❌ | Not stored, and **not** a blocker — the folder is still reclaimed. |
| Alternate data streams | ❌ | Not stored, and **not** a blocker — the main stream is archived and the folder is reclaimed. |
| Symlinks, junctions | ❌ | Not stored, **and a blocker** — see below. |

Attributes are written to **both** halves of the zip attribute word — the Unix
mode in the high 16 bits and the MS-DOS attribute byte in the low 8 — the way
Info-ZIP and 7-Zip do it. Python's own `ZipInfo.from_file` fills in only the Unix
half, which on Windows is synthesised and silently drops *hidden* and *system*.

Filling both matters because which half an extractor trusts depends on the
archive's `create_system` tag, and `zipfile` sets that from the *writing*
platform. An archive written on Windows is tagged MS-DOS, and Info-ZIP then
reads the DOS byte and ignores the Unix half — so the half Python fills in is
the half nobody reads. Verified against both tools on a Windows-written archive:

```
$ 7z l -slt d.zip           $ unzip -Z d.zip
emptydir    D                drwxrwxrwx  emptydir/
hidden.txt  H                -rw-rw-rw-  hidden.txt
ro.txt      R                -r--r--r--  ro.txt
```

Verification checks the stored attributes against the manifest before any
deletion, so retention is enforced rather than assumed.

**Metadata zip cannot hold does not stop the tool.** ACLs, alternate data
streams and owner/group are dropped and the folder is still reclaimed — the
archive's guarantee is about file *contents*. Only two things block deletion:
paths that cannot be archived at all (symlinks, junctions, FIFOs, devices) and
paths that could not be read.

**Symlinks and junctions are a different matter — they are not metadata.** They
point somewhere else, and following one means archiving and then deleting files
that live *outside* the folder being processed. Both are refused, and the folder
containing them is kept. Note that `DirEntry.is_symlink()` returns `False` for a
Windows junction, so junctions are detected via the reparse-point attribute
instead; see `_is_reparse_point`.

> **Note:** storing attributes is not the same as restoring them. Python's
> `zipfile.extractall` applies neither modes nor timestamps (its
> `_extract_member` calls no `chmod`/`utime`); `unzip` and 7-Zip do apply them.
> The archive carries the data either way.

## Behaviour on an existing archive

Default (non-`--strict`) mode appends missing files into the existing zip:

| Situation | Action |
| --- | --- |
| A member with the same name, size **and CRC32** | Skipped — the archive already holds these exact bytes. |
| Same name but **different content** | Stored as `name__dup1.ext`, and logged. Neither copy is lost. |
| Content already stored under `name__dupN.ext` from an earlier run | Recognised and skipped — re-running is idempotent. |
| Name not present | Added normally. |

The "already stored?" check walks the whole `name`, `name__dup1`, `name__dup2`,
… sequence rather than only the exact name. Checking just the exact name made
re-runs non-idempotent: a file stored as `f__dup1.txt` was never recognised
again, so every subsequent run appended another byte-identical `f__dup2.txt`,
`f__dup3.txt`, … and the archive grew without bound.

The "already archived" test compares **content**, not just name and size. Doing
it on size alone was a real data-loss bug: a file edited in place to the same
length matched the stored member, was declared already archived, and the source
was deleted while the archive still held the stale bytes. Comparing CRC32 costs
one read of the source — exactly what re-adding it would have cost anyway.

Use `-s`/`--strict` if you would rather never touch an existing archive.

## Performance

The workload is syscall-bound, not CPU-bound:

* `os.scandir` everywhere — it returns stat data cached from the directory read
  itself, avoiding a second `stat` per file. This is the main reason listing is
  far faster than `os.walk` + `getsize`.
* Directory recursion uses an explicit stack, so pathologically deep trees
  cannot exhaust the Python stack.
* Top-level folders run concurrently in a **thread** pool. Threads (not
  processes) are correct: the work is I/O syscalls and zlib compression, both of
  which release the GIL, and threads avoid pickling paths across processes.
* Within a folder the work is sequential — `zipfile.ZipFile` is not thread-safe,
  and one reader per device queue is usually optimal anyway.

Tuning notes:

* **The default is `store` — no compression.** The space this tool reclaims
  comes mostly from *consolidation*, not compression: a 3 KB file still occupies
  a full 4 KB cluster, so a million of them waste ~1 GB in slack alone, and
  packing them into one archive recovers that whatever the codec. `store` is
  also the fastest option and the most universally readable.

* **But compression is nearly free on small files, so consider `deflate` for
  text.** With many small files the run is bound by per-file overhead (syscalls,
  directory metadata, antivirus), not by the codec, so deflate costs only a few
  percent — and shrinks text-like payloads ~10×. Measured on this tool,
  4,000 × 2 KB files:

  | Payload | `store` | `deflate` | Cost | Archive size |
  | --- | --- | --- | --- | --- |
  | 2 KB × 4,000, incompressible | 28.7 s | 29.8 s | +4 % | 8.2 M → 8.2 M |
  | 2 KB × 4,000, text | 4.3 s | 4.5 s | +5 % | 8.2 M → 0.6 M |
  | 20 MB × 12, incompressible | 1.0 s | 6.9 s | +607 % | 240 M → 240 M |

  Effective throughput in the small-file rows is ~0.3 MB/s — orders of magnitude
  below both disk bandwidth and zlib's rate, which is what "overhead-bound"
  looks like. The CPU is idle waiting on I/O anyway, so compressing is close to
  free and can shrink text payloads by 10×.

* **On large files the gap widens sharply in `store`'s favour.** Once files are
  big enough to leave the per-file-overhead regime you become bandwidth-bound
  and zlib is the bottleneck: `store` sustained 246 MB/s versus deflate's
  34.8 MB/s above. That 34.8 MB/s is roughly zlib's real compression rate — it
  is slower than most modern storage, which is why the crossover exists and why
  `store` is the safer default for mixed or unknown payloads.

* **`-c zstd` removes that crossover entirely** (Python 3.14+; the option is
  hidden on older interpreters). Zstandard is ZIP compression method 93,
  registered in PKWARE's APPNOTE 6.3.7 (2020) and exposed by CPython via
  PEP 784. Measured on 240 MB, single-stream:

  | Payload | `store` | `deflate` | `zstd` |
  | --- | --- | --- | --- |
  | 240 MB incompressible | 691 MB/s | 36.6 MB/s | **528 MB/s** |
  | 240 MB text | 596 MB/s | 195 MB/s | **1041 MB/s** (→ 0.05 M) |

  On compressible data zstd is *faster than storing uncompressed*, because
  writing far fewer bytes costs less than the compression takes. This is the
  regime where "storage is slow, CPUs are fast" pays off — deflate simply is
  not fast enough to exploit it.

  ⚠️ **The catch is interoperability, and it is why zstd is not the default.**
  Method 93 is recent enough that many extractors cannot read it — notably the
  zip handler built into Windows Explorer. Recent 7-Zip, WinRAR and `zstd`-aware
  tooling handle it, but an archive you may need to open years from now on an
  unknown machine is exactly the wrong place to bet on decoder support. Choose
  `zstd` only when you control what will read the output.
* `--verify fast` skips the read-back pass, roughly halving I/O — but it only
  checks name and size, so it **cannot detect corruption**. Prefer the default
  `full` for anything you care about.
* **Memory scales with the largest folder, not the whole tree.** The manifest
  for a folder is held in RAM while it is processed — measured at ~240 bytes per
  entry, so roughly **0.24 GB per million files**. Peak usage is that figure for
  the largest folder, times the number of workers running concurrently:

  | Files in one folder | Manifest |
  | --- | --- |
  | 1,000,000 | ~0.24 GB |
  | 5,000,000 | ~1.2 GB |
  | 10,000,000 | ~2.4 GB |

  A tree of many modest folders is fine at any total size. If a *single* folder
  holds tens of millions of files, lower `-w` so fewer manifests are live at
  once. The manifest cannot be streamed away: it is the record of what was
  verified, and it must outlive the verify stage to drive deletion.

* Raise `-w` on NVMe; lower it to `1`–`2` on spinning disks, where concurrent
  streams cause seek thrash.
* On Windows, real-time antivirus scanning typically dominates the runtime for
  small files. Excluding the target path measurably speeds things up.

## Logging

Logs go to `~/small2zip.log` by default. Each folder brackets its work with
`=== BEGIN ... ===` / `=== END ... status=... ===`, so a run is easy to grep:

```bash
grep -E "BEGIN|END|published|FAILED|KEEP" ~/small2zip.log
```

At the default `INFO` level, per-file deletions are **not** logged — a
million-file run would otherwise produce a million lines. Use `-v` to get
per-file `DEBUG` detail when you need to trace an individual file. Warnings
(name collisions, kept files, blockers) and all errors are always logged.

## Caveats and known limitations

* **Symlinks and Windows junctions are never archived or followed.** Zip cannot
  round-trip them portably, and following one would archive and then delete
  files living outside the folder. A folder containing either is archived but
  **not deleted**, and is reported as `SKIP`. Resolve such folders manually.
* **Non-regular files** (FIFOs, devices, sockets) block deletion the same way.
  A folder with *nothing* archivable is left alone entirely — no empty zip is
  written for it.
* **`-c zstd` trades portability for speed.** ZIP method 93 is valid per the
  spec but not universally decodable — Windows Explorer's built-in extractor
  cannot open it. Archives are long-lived; prefer `deflate` or `store` unless
  you know what will read them. The option is absent entirely on Python < 3.14.
* **Ownership, ACLs and alternate data streams are lost, and do not block.**
  Zip has nowhere to put them, so a file carrying them is archived by content
  and its folder is still reclaimed. Unix mode bits and the DOS attribute bits
  *are* retained (see [What is retained](#what-is-retained)). Do not use this
  where ACL or ADS metadata matters.
* **Timestamps lose precision.** Zip's base format stores 2-second DOS
  resolution, so restored mtimes can be up to 2 s early. Sub-second precision
  would need an extra field (`0x5455`/`0x000a`), which is not currently written.
  The tool's own change detection is unaffected — it compares `st_mtime_ns` from
  disk, not the archived timestamp.
* **Timestamps before 1980 are clamped**, because zip cannot express them at
  all. Such a file would otherwise be permanently unarchivable and its folder
  never reclaimable, which is a far worse outcome than an approximate mtime.
* **Concurrent modification is not fully guarded.** A file created *after* the
  archive scan is not archived, and is left on disk (so the folder survives). A
  file *modified* after archiving is detected and kept, and one that becomes
  unreadable mid-archive is reported as a blocker. Do not run this against a
  tree another process is actively writing to.
* **A top-level folder that is entirely empty is removed without an archive** —
  there is nothing in it to lose. Empty *sub*-directories are archived as
  directory members and do survive.
* **No cross-device atomicity.** The `.partial` and final `.zip` live in the same
  directory, so `os.replace` is atomic. Do not change the destination to another
  volume without revisiting this.
* **Disk space.** Appending to an existing archive copies it first, so peak
  usage is roughly `old_zip + new_zip` for that folder. Free space is not
  pre-checked; a full disk fails verification and the source folder survives.
* The default `~/small2zip.log` grows without rotation. Trim it periodically.

## Tests

```bash
python test_small2zip.py                  # stdlib unittest, no dependencies
python -m pytest test_small2zip.py -q     # if pytest is installed
```

The suite runs against real temporary directories rather than a mocked
filesystem — the invariant is about what is genuinely on disk — and completes in
about a second.

Tests are weighted toward the safety invariant rather than feature coverage.
Every way the tool could lose data has an explicit test: verification failure,
cancellation mid-archive, undeletable files, files mutated between archive and
delete, sources that vanish mid-write, and same-name/different-content
collisions when appending.

When adding a feature, add its safety test. At minimum, re-confirm:

1. Cancellation mid-archive leaves every source file on disk and no `.partial`.
2. A verification failure leaves the source folder untouched.
3. An undeletable file leaves that file on disk **and** present in the archive.
4. A file whose content changed is never mistaken for its archived copy.

A regression test is only worth having if it fails against the bug it describes.
When you fix a data-loss bug, verify the new test fails with the fix reverted.
