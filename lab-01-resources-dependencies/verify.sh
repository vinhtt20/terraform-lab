#!/usr/bin/env bash
# verify.sh — Lab 01 grader
# Compatible with bash 3.2 (macOS default): no associative arrays, no mapfile.

set -euo pipefail

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR="${LAB_DIR}/starter"
PASS=0
FAIL=0

pass() { echo "  ✅ $1"; PASS=$((PASS+1)); }
fail() { echo "  ❌ $1"; FAIL=$((FAIL+1)); }

echo "▶ Lab 01 — verify"

# --- 1. fmt -----------------------------------------------------------------
if terraform -chdir="${WORK_DIR}" fmt -check -recursive >/dev/null 2>&1; then
  pass "terraform fmt sạch"
else
  fail "terraform fmt phát hiện file chưa format (chạy 'terraform fmt' trong starter/)"
fi

# --- 2. init + validate -----------------------------------------------------
if [ ! -d "${WORK_DIR}/.terraform" ]; then
  if ! terraform -chdir="${WORK_DIR}" init -input=false -no-color >/dev/null 2>&1; then
    fail "terraform init thất bại (xem 'terraform init' để biết chi tiết)"
  fi
fi

if terraform -chdir="${WORK_DIR}" validate -no-color >/dev/null 2>&1; then
  pass "terraform validate pass"
else
  fail "terraform validate thất bại"
fi

# --- 3. state assertions ----------------------------------------------------
STATE_FILE="${WORK_DIR}/terraform.tfstate"
if [ ! -f "${STATE_FILE}" ]; then
  fail "chưa có terraform.tfstate — bạn đã chạy 'terraform apply' chưa?"
else
  STATE_LIST=$(terraform -chdir="${WORK_DIR}" state list 2>/dev/null || echo "")

  # Expected resources (5 total).
  EXPECTED="docker_network.app
docker_image.redis
docker_image.nginx
docker_container.db
docker_container.web"

  # bash 3.2-friendly loop: feed via printf, read line by line.
  MISSING=0
  while IFS= read -r addr; do
    [ -z "${addr}" ] && continue
    if echo "${STATE_LIST}" | grep -qx "${addr}"; then
      pass "state có ${addr}"
    else
      fail "state thiếu ${addr}"
      MISSING=$((MISSING+1))
    fi
  done <<EOF
${EXPECTED}
EOF

  # Verify a key attribute: web container exposes port 8081.
  if terraform -chdir="${WORK_DIR}" state show docker_container.web 2>/dev/null \
       | grep -qE 'external\s+=\s+8081'; then
    pass "web container map cổng 8081"
  else
    fail "web container chưa map cổng 8081"
  fi

  # Verify outputs.
  WEB_URL=$(terraform -chdir="${WORK_DIR}" output -raw web_url 2>/dev/null || echo "")
  if echo "${WEB_URL}" | grep -q 'http://localhost:8081'; then
    pass "output 'web_url' chứa http://localhost:8081"
  else
    fail "output 'web_url' không đúng (giá trị: '${WEB_URL}')"
  fi

  NET_ID=$(terraform -chdir="${WORK_DIR}" output -raw network_id 2>/dev/null || echo "")
  if [ -n "${NET_ID}" ] && [ ${#NET_ID} -ge 8 ]; then
    pass "output 'network_id' tồn tại (${NET_ID:0:12}...)"
  else
    fail "output 'network_id' rỗng hoặc quá ngắn"
  fi

  CONTAINERS_JSON=$(terraform -chdir="${WORK_DIR}" output -json containers 2>/dev/null || echo "[]")
  if echo "${CONTAINERS_JSON}" | grep -q 'tflab-01-web' \
     && echo "${CONTAINERS_JSON}" | grep -q 'tflab-01-db'; then
    pass "output 'containers' chứa cả tflab-01-web và tflab-01-db"
  else
    fail "output 'containers' thiếu một trong hai tên container"
  fi

  # Cross-check with Docker (only if docker CLI present).
  if command -v docker >/dev/null 2>&1; then
    if docker inspect -f '{{.State.Running}}' tflab-01-web 2>/dev/null | grep -q true; then
      pass "container tflab-01-web đang chạy"
    else
      fail "container tflab-01-web không chạy"
    fi

    if docker inspect -f '{{.State.Running}}' tflab-01-db 2>/dev/null | grep -q true; then
      pass "container tflab-01-db đang chạy"
    else
      fail "container tflab-01-db không chạy"
    fi

    # Verify both containers are attached to the network.
    if command -v jq >/dev/null 2>&1; then
      NET_NAMES=$(docker network inspect tflab-01-net 2>/dev/null \
                    | jq -r '.[0].Containers[].Name' 2>/dev/null \
                    | sort | tr '\n' ' ')
      if echo "${NET_NAMES}" | grep -q 'tflab-01-web' \
         && echo "${NET_NAMES}" | grep -q 'tflab-01-db'; then
        pass "network tflab-01-net có cả 2 container attach"
      else
        fail "network tflab-01-net thiếu container (thấy: ${NET_NAMES})"
      fi
    fi
  fi

  # --- 4. Idempotency: second plan must show no changes ---------------------
  PLAN_OUT=$(terraform -chdir="${WORK_DIR}" plan -detailed-exitcode -no-color -input=false 2>/dev/null; echo "EXIT:$?")
  PLAN_EXIT=$(echo "${PLAN_OUT}" | tail -1 | sed 's/^EXIT://')
  # detailed-exitcode: 0 = no changes, 2 = diff, 1 = error
  if [ "${PLAN_EXIT}" = "0" ]; then
    pass "terraform plan lần 2 báo 0 changes (idempotent)"
  elif [ "${PLAN_EXIT}" = "2" ]; then
    fail "terraform plan lần 2 vẫn có changes — không idempotent"
  else
    fail "terraform plan lần 2 lỗi (exit ${PLAN_EXIT})"
  fi
fi

echo
echo "Kết quả: ${PASS} pass, ${FAIL} fail"
if [ ${FAIL} -eq 0 ]; then
  echo "PASS"
  exit 0
else
  echo "FAIL"
  exit 1
fi
