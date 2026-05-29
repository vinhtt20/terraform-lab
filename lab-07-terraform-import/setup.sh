#!/usr/bin/env bash
# setup.sh — Lab 07: create the "legacy" Docker resources OUTSIDE Terraform.
#
# Simulates the situation where an operator created a container + volume by
# hand (`docker run`, `docker volume create`). The lab then teaches you how
# to bring that pre-existing state under Terraform management via `import`.
#
# Idempotent: safe to re-run; existing resources are left alone.

set -euo pipefail

CONTAINER="tflab-07-legacy-app"
VOLUME="tflab-07-legacy-data"
IMAGE="nginx:1.27-alpine"
PORT="8110"

echo "▶ Lab 07 — setup (creating legacy resources outside Terraform)"

# --- 1. ensure image is present locally (this is NOT what we import) -----
if docker image inspect "${IMAGE}" >/dev/null 2>&1; then
  echo "  ✓ image ${IMAGE} đã có"
else
  echo "  ↓ pulling ${IMAGE} ..."
  docker pull "${IMAGE}" >/dev/null
  echo "  ✓ image ${IMAGE} pulled"
fi

# --- 2. volume ------------------------------------------------------------
if docker volume inspect "${VOLUME}" >/dev/null 2>&1; then
  echo "  ✓ volume ${VOLUME} đã có"
else
  docker volume create "${VOLUME}" >/dev/null
  echo "  ✓ volume ${VOLUME} created"
fi

# --- 3. container ---------------------------------------------------------
if docker container inspect "${CONTAINER}" >/dev/null 2>&1; then
  echo "  ✓ container ${CONTAINER} đã có"
else
  docker run -d \
    --name "${CONTAINER}" \
    -p "${PORT}:80" \
    -v "${VOLUME}:/var/data" \
    --restart unless-stopped \
    "${IMAGE}" >/dev/null
  echo "  ✓ container ${CONTAINER} started (port ${PORT})"
fi

echo
echo "Legacy stack đã sẵn sàng. Tiếp theo:"
echo "  cd starter && terraform init"
echo "  # rồi đọc README phần 'Hướng dẫn làm'."
