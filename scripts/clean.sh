#!/usr/bin/env bash
# Clean up Docker resources created by Nexus-engine builds.
set -euo pipefail

source_dir="$(dirname "$0")/.."

echo "==> Removing Nexus-engine Docker volumes and dangling images..."
docker image prune -f --filter "label=component=nexus-engine" 2>/dev/null || true

rm -rf "${source_dir}/.zig-cache" "${source_dir}/zig-out" "${source_dir}/build" \
       "${source_dir}/zig-pkg" "${source_dir}/libs/zGameLib/.zig-cache" 2>/dev/null || true
echo "==> Done."
