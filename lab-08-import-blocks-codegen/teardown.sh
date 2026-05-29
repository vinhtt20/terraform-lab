#!/usr/bin/env bash
# teardown.sh — Lab 08: remove the legacy stack.

set -u

NET="tflab-08-net"
VOLS="data1 data2"
APPS="app1 app2 app3"
IMAGE="nginx:1.27-alpine"

echo "▶ Lab 08 — teardown"

# Remove containers first (they hold network & volume references).
for a in ${APPS}; do
  c="tflab-08-${a}"
  docker rm -f "${c}" >/dev/null 2>&1 && echo "  ✓ removed container ${c}" \
                                       || echo "  · container ${c} không tồn tại"
done

for v in ${VOLS}; do
  vol="tflab-08-${v}"
  docker volume rm "${vol}" >/dev/null 2>&1 && echo "  ✓ removed volume ${vol}" \
                                            || echo "  · volume ${vol} không tồn tại"
done

docker network rm "${NET}" >/dev/null 2>&1 && echo "  ✓ removed network ${NET}" \
                                           || echo "  · network ${NET} không tồn tại"

# Image left in place to avoid re-pulling between labs.
# docker rmi "${IMAGE}" >/dev/null 2>&1 && echo "  ✓ removed image ${IMAGE}" || true

echo "Done."
