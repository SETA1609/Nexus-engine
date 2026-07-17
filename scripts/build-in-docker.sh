#!/usr/bin/env bash
# Build Nexus-engine inside the Docker container.
# Usage: ./scripts/build-in-docker.sh [step]
#   step: pipeline (default), build-lib, build-runtime, run, or any zig build step
set -euo pipefail

STEP="${1:-pipeline}"

cd "$(dirname "$0")/.."

git submodule update --init --recursive

echo "==> Nexus-engine: zig build ${STEP}"
zig build "${STEP}"
