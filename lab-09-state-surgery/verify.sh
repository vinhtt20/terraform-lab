#!/usr/bin/env bash
# verify.sh — Lab 09 grader
# Compatible with bash 3.2 (macOS default): no associative arrays, no mapfile.

set -euo pipefail

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR="${LAB_DIR}/starter"
PASS=0
FAIL=0

pass() { echo "  ✅ $1"; PASS=$((PASS+1)); }
fail() { echo "  ❌ $1"; FAIL=$((FAIL+1)); }

echo "▶ Lab 09 — verify"

# --- 1. fmt -----------------------------------------------------------------
if terraform -chdir="${WORK_DIR}" fmt -check -recursive >/dev/null 2>&1; then
  pass "terraform fmt sạch (recursive)"
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

# --- 3. declarative-blocks check (must use moved {} and removed {}) ----------
if grep -Eq '^[[:space:]]*moved[[:space:]]*\{' "${WORK_DIR}/main.tf"; then
  pass "main.tf có 'moved {}' blocks (refactor declarative)"
else
  fail "main.tf KHÔNG có 'moved {}' block — lab này yêu cầu declarative migration"
fi

if grep -Eq '^[[:space:]]*removed[[:space:]]*\{' "${WORK_DIR}/main.tf"; then
  pass "main.tf có 'removed {}' block"
else
  fail "main.tf KHÔNG có 'removed {}' block — bạn cần deprecate web3 declarative"
fi

if grep -Eq 'destroy[[:space:]]*=[[:space:]]*false' "${WORK_DIR}/main.tf"; then
  pass "removed block có 'destroy = false' (giữ live container)"
else
  fail "removed block thiếu 'destroy = false' → sẽ destroy web3 (sai requirement)"
fi

# --- 4. state assertions ----------------------------------------------------
STATE_FILE="${WORK_DIR}/terraform.tfstate"
if [ ! -f "${STATE_FILE}" ]; then
  fail "chưa có terraform.tfstate — bạn đã 'terraform apply' chưa?"
else
  STATE_LIST=$(terraform -chdir="${WORK_DIR}" state list 2>/dev/null || echo "")

  EXPECTED_PRESENT='docker_image.nginx
docker_container.web["web1"]
docker_container.web["web2"]'

  while IFS= read -r addr; do
    [ -z "${addr}" ] && continue
    if echo "${STATE_LIST}" | grep -qxF "${addr}"; then
      pass "state có ${addr}"
    else
      fail "state thiếu ${addr}"
    fi
  done <<EOF
${EXPECTED_PRESENT}
EOF

  EXPECTED_ABSENT='docker_container.web1
docker_container.web2
docker_container.web3'

  while IFS= read -r addr; do
    [ -z "${addr}" ] && continue
    if echo "${STATE_LIST}" | grep -qxF "${addr}"; then
      fail "state vẫn còn legacy address ${addr} (chưa migrate hoàn toàn)"
    else
      pass "state không còn ${addr}"
    fi
  done <<EOF
${EXPECTED_ABSENT}
EOF
fi

# --- 5. live Docker objects — all 3 web containers must survive --------------
if ! command -v docker >/dev/null 2>&1; then
  fail "docker CLI không có"
else
  for name in tflab-09-web1 tflab-09-web2 tflab-09-web3; do
    if docker inspect -f '{{.State.Running}}' "${name}" 2>/dev/null | grep -q true; then
      pass "container ${name} vẫn đang chạy (không bị destroy)"
    else
      fail "container ${name} không chạy — refactor đã destroy nhầm container?"
    fi
  done
fi

# --- 6. outputs --------------------------------------------------------------
if [ -f "${STATE_FILE}" ] && command -v jq >/dev/null 2>&1; then
  URLS_JSON=$(terraform -chdir="${WORK_DIR}" output -json urls 2>/dev/null || echo "{}")
  EXPECTED_PAIRS='web1:8191 web2:8192'
  for pair in ${EXPECTED_PAIRS}; do
    key="$(echo "${pair}" | cut -d: -f1)"
    port="$(echo "${pair}" | cut -d: -f2)"
    got=$(echo "${URLS_JSON}" | jq -r --arg k "${key}" '.[$k] // empty')
    expected="http://localhost:${port}"
    if [ "${got}" = "${expected}" ]; then
      pass "output urls.${key} = ${expected}"
    else
      fail "output urls.${key} = '${got}' (mong đợi '${expected}')"
    fi
  done
fi

# --- 7. idempotency ----------------------------------------------------------
if [ -f "${STATE_FILE}" ]; then
  PLAN_OUT=$(terraform -chdir="${WORK_DIR}" plan -detailed-exitcode -no-color -input=false 2>/dev/null; echo "EXIT:$?")
  PLAN_EXIT=$(echo "${PLAN_OUT}" | tail -1 | sed 's/^EXIT://')
  if [ "${PLAN_EXIT}" = "0" ]; then
    pass "terraform plan = 0 changes (idempotent)"
  elif [ "${PLAN_EXIT}" = "2" ]; then
    fail "terraform plan vẫn có changes — config chưa khớp state"
  else
    fail "terraform plan lỗi (exit ${PLAN_EXIT})"
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
