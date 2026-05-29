#!/usr/bin/env bash
# verify.sh — Lab 04 grader
# Compatible with bash 3.2 (macOS default).

set -euo pipefail

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR="${LAB_DIR}/starter"
PASS=0
FAIL=0

pass() { echo "  ✅ $1"; PASS=$((PASS+1)); }
fail() { echo "  ❌ $1"; FAIL=$((FAIL+1)); }

echo "▶ Lab 04 — verify"

# --- 1. fmt -----------------------------------------------------------------
if terraform -chdir="${WORK_DIR}" fmt -check -recursive >/dev/null 2>&1; then
  pass "terraform fmt sạch"
else
  fail "terraform fmt phát hiện file chưa format"
fi

# --- 2. init + validate -----------------------------------------------------
if [ ! -d "${WORK_DIR}/.terraform" ]; then
  if ! terraform -chdir="${WORK_DIR}" init -input=false -no-color >/dev/null 2>&1; then
    fail "terraform init thất bại"
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

  EXPECTED='data.docker_registry_image.nginx
data.local_file.motd
docker_image.east
docker_image.west
docker_container.east
docker_container.west'

  while IFS= read -r addr; do
    [ -z "${addr}" ] && continue
    if echo "${STATE_LIST}" | grep -qxF "${addr}"; then
      pass "state có ${addr}"
    else
      fail "state thiếu ${addr}"
    fi
  done <<EOF
${EXPECTED}
EOF

  # digest format
  DIGEST=$(terraform -chdir="${WORK_DIR}" output -raw digest 2>/dev/null || echo "")
  if echo "${DIGEST}" | grep -qE '^sha256:[a-f0-9]{64}$'; then
    pass "output 'digest' khớp regex ^sha256:[a-f0-9]{64}$"
  else
    fail "output 'digest' không phải sha256 hợp lệ (giá trị: '${DIGEST:0:32}...')"
  fi

  # URLs
  EAST=$(terraform -chdir="${WORK_DIR}" output -raw east_url 2>/dev/null || echo "")
  if echo "${EAST}" | grep -q 'http://localhost:8090'; then
    pass "output 'east_url' = http://localhost:8090"
  else
    fail "output 'east_url' = '${EAST}' (mong đợi http://localhost:8090)"
  fi
  WEST=$(terraform -chdir="${WORK_DIR}" output -raw west_url 2>/dev/null || echo "")
  if echo "${WEST}" | grep -q 'http://localhost:8091'; then
    pass "output 'west_url' = http://localhost:8091"
  else
    fail "output 'west_url' = '${WEST}' (mong đợi http://localhost:8091)"
  fi

  # motd_sha256 — 64 hex chars
  MOTD_HASH=$(terraform -chdir="${WORK_DIR}" output -raw motd_sha256 2>/dev/null || echo "")
  if echo "${MOTD_HASH}" | grep -qE '^[a-f0-9]{64}$'; then
    pass "output 'motd_sha256' là 64 hex chars"
  else
    fail "output 'motd_sha256' không phải 64 hex chars (giá trị: '${MOTD_HASH}')"
  fi

  # Docker cross-check
  if command -v docker >/dev/null 2>&1; then
    for region in east west; do
      if docker inspect -f '{{.State.Running}}' "tflab-04-${region}" 2>/dev/null | grep -q true; then
        pass "container tflab-04-${region} đang chạy"
      else
        fail "container tflab-04-${region} không chạy"
      fi
    done
  fi

  # Idempotency
  PLAN_OUT=$(terraform -chdir="${WORK_DIR}" plan -detailed-exitcode -no-color -input=false 2>/dev/null; echo "EXIT:$?")
  PLAN_EXIT=$(echo "${PLAN_OUT}" | tail -1 | sed 's/^EXIT://')
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
