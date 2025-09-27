#!/usr/bin/env bash
set -euo pipefail

REF="${1:-}"
if [[ -z "${REF}" ]]; then
  echo "Usage: $0 <image:tag>"; exit 1
fi

echo ">> Inspecting manifest for ${REF}"
docker buildx imagetools inspect "${REF}" || {
  echo "ERROR: Couldn't inspect image manifest."; exit 1;
}
