#!/usr/bin/env bash
# teardown.sh — Lab 07: remove the legacy resources.
#
# Run this AFTER you have either (a) successfully completed the lab and run
# `terraform destroy` in starter/, or (b) want to abandon the lab and clean
# up by hand. Safe to run multiple times.

set -u

CONTAINER="tflab-07-legacy-app"
VOLUME="tflab-07-legacy-data"
IMAGE="nginx:1.27-alpine"

echo "▶ Lab 07 — teardown"

docker rm -f "${CONTAINER}" >/dev/null 2>&1 && echo "  ✓ container ${CONTAINER} removed" \
                                            || echo "  · container ${CONTAINER} không tồn tại"

docker volume rm "${VOLUME}" >/dev/null 2>&1 && echo "  ✓ volume ${VOLUME} removed" \
                                             || echo "  · volume ${VOLUME} không tồn tại"

# Image removal is optional — keep it commented to avoid re-pulling between labs.
# docker rmi "${IMAGE}" >/dev/null 2>&1 && echo "  ✓ image ${IMAGE} removed" \
#                                       || echo "  · image ${IMAGE} không tồn tại"

echo "Done."
