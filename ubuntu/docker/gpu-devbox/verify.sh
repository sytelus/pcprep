#!/usr/bin/env bash
# Verify a multi-arch Docker image by inspecting its manifest and metadata.
# Usage: ./verify.sh <image:tag>
#   Examples:
#     ./verify.sh sytelus/gpu-devbox:2025.01.15
#     ./verify.sh sytelus/gpu-devbox:latest
set -euo pipefail

REF="${1:-}"
if [[ -z "${REF}" ]]; then
    echo "Usage: $0 <image:tag>"
    echo "  Examples:"
    echo "    $0 sytelus/gpu-devbox:latest"
    echo "    $0 sytelus/gpu-devbox:2025.01.15"
    exit 1
fi

echo "=========== Multi-arch Manifest ==========="
if ! docker buildx imagetools inspect "${REF}"; then
    echo "ERROR: Couldn't inspect image manifest for ${REF}" >&2
    echo "  - Check that the image exists and is accessible" >&2
    echo "  - For private registries, ensure you're logged in" >&2
    exit 1
fi

echo ""
echo "=========== Platform Availability ==========="
# Extract and display available platforms
docker buildx imagetools inspect "${REF}" --raw 2>/dev/null | \
    python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    if 'manifests' in data:
        for m in data['manifests']:
            p = m.get('platform', {})
            print(f\"  - {p.get('os', 'unknown')}/{p.get('architecture', 'unknown')}\")
    else:
        print('  Single-arch image')
except:
    print('  Unable to parse manifest')
" 2>/dev/null || echo "  Unable to determine platforms"

echo ""
echo "=========== Image Labels ==========="
# Try to inspect labels (works for local images)
if docker image inspect "${REF}" >/dev/null 2>&1; then
    docker image inspect "${REF}" --format '{{range $k, $v := .Config.Labels}}  {{$k}}: {{$v}}{{"\n"}}{{end}}' 2>/dev/null || echo "  No labels available"
else
    echo "  (Pull image locally to inspect labels)"
fi

echo ""
echo "Verification complete for ${REF}"
