#!/usr/bin/env python3
"""Import and print versions for pcprep's managed macOS "main" Python stack.

This script is executed by pcprep's managed main interpreter from both
`setup_python_ai.sh` and `verify_setup.sh`. Keeping the package list and the
distribution-to-module mapping here avoids the two shell scripts drifting apart.
It reads the package set directly from the repo's requirements files so the
installer and verifier stay aligned as that list evolves.
"""

from __future__ import annotations

import importlib
import importlib.metadata as metadata
from pathlib import Path
import re
import sys

DIST_NAME_RE = re.compile(r"^\s*([A-Za-z0-9_.-]+)")

# Packages that should be verified via distribution metadata only, not by a
# top-level import.  This avoids relying on unstable or unnecessary top-level
# import surfaces for packaging/bootstrap utilities and Jupyter metapackages.
METADATA_ONLY = {
    "pip",
    "setuptools",
    "wheel",
    "jupyter",
    "jupyterlab",
}

# Distros whose import name differs from the published package name.
IMPORT_NAME_OVERRIDES = {
    "scikit-learn": "sklearn",
    "mlx-lm": "mlx_lm",
}


def requirements_paths_from_argv() -> list[Path]:
    if len(sys.argv) > 1:
        return [Path(arg).resolve() for arg in sys.argv[1:]]
    return [(Path(__file__).resolve().parent / "requirements-ai.txt").resolve()]


def parse_requirement_dists(requirements_paths: list[Path]) -> list[str]:
    dist_names: list[str] = []
    seen: set[str] = set()

    for requirements_path in requirements_paths:
        for raw_line in requirements_path.read_text(encoding="utf-8").splitlines():
            line = raw_line.split("#", 1)[0].strip()
            if not line:
                continue

            match = DIST_NAME_RE.match(line)
            if not match:
                continue

            dist_name = match.group(1)
            if dist_name not in seen:
                seen.add(dist_name)
                dist_names.append(dist_name)

    return dist_names


def import_name_for_dist(dist_name: str) -> str:
    if dist_name in METADATA_ONLY:
        return ""

    return IMPORT_NAME_OVERRIDES.get(dist_name, dist_name.replace("-", "_"))


def main() -> None:
    for dist_name in parse_requirement_dists(requirements_paths_from_argv()):
        module_name = import_name_for_dist(dist_name)
        try:
            dist_version = metadata.version(dist_name)
        except metadata.PackageNotFoundError as exc:
            raise SystemExit(f"Missing required distribution: {dist_name}") from exc

        if module_name:
            try:
                module = importlib.import_module(module_name)
            except Exception as exc:
                raise SystemExit(
                    f"Distribution '{dist_name}' is installed but import failed for module '{module_name}': {exc}"
                ) from exc
            module_version = getattr(module, "__version__", dist_version)
            print(f"{dist_name}: {module_version}")
        else:
            print(f"{dist_name}: {dist_version}")


if __name__ == "__main__":
    main()
