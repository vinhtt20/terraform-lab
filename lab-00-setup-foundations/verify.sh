#!/usr/bin/env bash
# verify.sh — Lab 00 grader
# Compatible with bash 3.2 (macOS default).

set -euo pipefail

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR="${LAB_DIR}/starter"
PASS=0
FAIL=0

pass() { echo "  ✅ $1"; PASS=$((PASS+1)); }
fail() { echo "  ❌ $1"; FAIL=$((FAIL+1)); }

echo "▶ Lab 00 — verify"

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

# --- 3. state assertions (only if state exists) -----------------------------
STATE_FILE="${WORK_DIR}/terraform.tfstate"
if [ ! -f "${STATE_FILE}" ]; then
  fail "chưa có terraform.tfstate — bạn đã chạy 'terraform apply' chưa?"
else
  STATE_LIST=$(terraform -chdir="${WORK_DIR}" state list 2>/dev/null || echo "")

  if echo "${STATE_LIST}" | grep -qx 'docker_image.nginx'; then
    pass "có resource docker_image.nginx trong state"
  else
    fail "thiếu docker_image.nginx trong state"
  fi

  if echo "${STATE_LIST}" | grep -qx 'docker_container.hello'; then
    pass "có resource docker_container.hello trong state"
  else
    fail "thiếu docker_container.hello trong state"
  fi

  # Verify container name attribute via state show.
  if terraform -chdir="${WORK_DIR}" state show docker_container.hello 2>/dev/null \
       | grep -qE '^\s*name\s+=\s+"tflab-00-hello"'; then
    pass "container có tên 'tflab-00-hello'"
  else
    fail "container không có tên 'tflab-00-hello'"
  fi

  # Verify port mapping via terraform output / state.
  if terraform -chdir="${WORK_DIR}" state show docker_container.hello 2>/dev/null \
       | grep -qE 'external\s+=\s+8080'; then
    pass "container map cổng 8080"
  else
    fail "container chưa map cổng 8080 ra host"
  fi

  # Verify output `url`.
  URL=$(terraform -chdir="${WORK_DIR}" output -raw url 2>/dev/null || echo "")
  if echo "${URL}" | grep -q 'http://localhost:8080'; then
    pass "output 'url' chứa http://localhost:8080"
  else
    fail "output 'url' không đúng (giá trị: '${URL}')"
  fi

  # Verify output `container_id` is a non-empty string of hex chars.
  CID=$(terraform -chdir="${WORK_DIR}" output -raw container_id 2>/dev/null || echo "")
  if [ -n "${CID}" ] && [ ${#CID} -ge 12 ]; then
    pass "output 'container_id' tồn tại (${CID:0:12}...)"
  else
    fail "output 'container_id' rỗng hoặc quá ngắn"
  fi

  # Cross-check with Docker itself (only if docker CLI present).
  if command -v docker >/dev/null 2>&1; then
    if docker inspect tflab-00-hello >/dev/null 2>&1; then
      pass "docker inspect tflab-00-hello OK"
    else
      fail "không tìm thấy container tflab-00-hello trong Docker"
    fi
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
