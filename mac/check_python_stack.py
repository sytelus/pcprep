#!/usr/bin/env python3
"""Import and print versions for pcprep's managed macOS Python stack.

This script is executed by the target Homebrew Python interpreter from both
`setup_python_ai.sh` and `verify_setup.sh`.  Keeping the package list and the
distribution-to-module mapping here avoids the two shell scripts drifting apart.
"""

from __future__ import annotations

import importlib
import importlib.metadata as metadata


# Each entry is (distribution_name, importable_module_name_or_empty_string).
# The metadata lookup confirms the distribution is installed; the import step
# confirms the runtime module is actually usable.  The `jupyter` metapackage is
# intentionally metadata-only because its top-level import surface is not a
# stable part of normal user workflows.
PACKAGES = [
    ("rich", "rich"),
    ("pytest", "pytest"),
    ("pandas", "pandas"),
    ("scikit-learn", "sklearn"),
    ("matplotlib", "matplotlib"),
    ("jupyter", ""),
    ("tensorflow", "tensorflow"),
    ("tensorboard", "tensorboard"),
    ("keras", "keras"),
    ("transformers", "transformers"),
    ("datasets", "datasets"),
    ("wandb", "wandb"),
    ("accelerate", "accelerate"),
    ("einops", "einops"),
    ("tokenizers", "tokenizers"),
    ("sentencepiece", "sentencepiece"),
    ("lightning", "lightning"),
]


def main() -> None:
    for dist_name, module_name in PACKAGES:
        dist_version = metadata.version(dist_name)
        if module_name:
            module = importlib.import_module(module_name)
            module_version = getattr(module, "__version__", dist_version)
            print(f"{dist_name}: {module_version}")
        else:
            print(f"{dist_name}: {dist_version}")


if __name__ == "__main__":
    main()
