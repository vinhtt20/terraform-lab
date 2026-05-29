#!/usr/bin/env bash
# setup.sh — Lab 08: create the "legacy stack" of 6 Docker resources.
#
# Pre-existing stack (created OUTSIDE Terraform):
#   - 1 user-defined bridge network: tflab-08-net
#   - 2 named volumes:               tflab-08-data1, tflab-08-data2
#   - 3 nginx containers:            tflab-08-app1 (8111, mount data1)
#                                    tflab-08-app2 (8112, mount data2)
#                                    tflab-08-app3 (8113, no volume)
#
# Idempotent: re-running leaves existing resources alone.

set -euo pipefail

NET="tflab-08-net"
IMAGE="nginx:1.27-alpine"
VOLS="data1 data2"
APPS="app1:8111:data1 app2:8112:data2 app3:8113:"

echo "▶ Lab 08 — setup (creating legacy stack outside Terraform)"

# --- 1. image -------------------------------------------------------------
if docker image inspect "${IMAGE}" >/dev/null 2>&1; then
  echo "  ✓ image ${IMAGE} đã có"
else
  echo "  ↓ pulling ${IMAGE} ..."
  docker pull "${IMAGE}" >/dev/null
fi

# --- 2. network -----------------------------------------------------------
if docker network inspect "${NET}" >/dev/null 2>&1; then
  echo "  ✓ network ${NET} đã có"
else
  docker network create --driver bridge "${NET}" >/dev/null
  echo "  ✓ network ${NET} created"
fi

# --- 3. volumes -----------------------------------------------------------
for v in ${VOLS}; do
  full="tflab-08-${v}"
  if docker volume inspect "${full}" >/dev/null 2>&1; then
    echo "  ✓ volume ${full} đã có"
  else
    docker volume create "${full}" >/dev/null
    echo "  ✓ volume ${full} created"
  fi
done

# --- 4. containers --------------------------------------------------------
for spec in ${APPS}; do
  name="$(echo "${spec}" | cut -d: -f1)"
  port="$(echo "${spec}" | cut -d: -f2)"
  vol="$(echo "${spec}" | cut -d: -f3)"
  cname="tflab-08-${name}"

  if docker container inspect "${cname}" >/dev/null 2>&1; then
    echo "  ✓ container ${cname} đã có"
    continue
  fi

  if [ -n "${vol}" ]; then
    docker run -d \
      --name "${cname}" \
      --network "${NET}" \
      -p "${port}:80" \
      -v "tflab-08-${vol}:/var/data" \
      --restart unless-stopped \
      "${IMAGE}" >/dev/null
  else
    docker run -d \
      --name "${cname}" \
      --network "${NET}" \
      -p "${port}:80" \
      --restart unless-stopped \
      "${IMAGE}" >/dev/null
  fi
  echo "  ✓ container ${cname} started (port ${port}${vol:+, vol=tflab-08-${vol}})"
done

echo
echo "Legacy stack ready (1 network + 2 volumes + 3 containers)."
echo "Next:"
echo "  cd starter && terraform init"
echo "  # Read README 'Hướng dẫn làm' for the import workflow."
