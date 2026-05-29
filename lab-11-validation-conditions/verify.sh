#!/usr/bin/env bash
# verify.sh — Lab 11 grader (validation, preconditions, postconditions, check {})
# Compatible with bash 3.2 (macOS default).

set -euo pipefail

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR="${LAB_DIR}/starter"
PASS=0
FAIL=0

pass() { echo "  ✅ $1"; PASS=$((PASS+1)); }
fail() { echo "  ❌ $1"; FAIL=$((FAIL+1)); }

echo "▶ Lab 11 — verify"

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

# --- 3. variable validation blocks ------------------------------------------
VARS_FILE="${WORK_DIR}/variables.tf"
COUNT_VALIDATION=$(grep -Ec '^[[:space:]]*validation[[:space:]]*\{' "${VARS_FILE}" 2>/dev/null || echo "0")
COUNT_VALIDATION=$(echo "${COUNT_VALIDATION}" | tr -d ' ')
if [ "${COUNT_VALIDATION}" -ge 3 ]; then
  pass "variables.tf có ${COUNT_VALIDATION} validation block(s) (>= 3)"
else
  fail "variables.tf chỉ có ${COUNT_VALIDATION} validation block(s) — cần >= 3"
fi

# --- 4. precondition / postcondition / check block --------------------------
MAIN_FILE="${WORK_DIR}/main.tf"

if grep -Eq '^[[:space:]]*precondition[[:space:]]*\{' "${MAIN_FILE}"; then
  pass "main.tf có precondition block"
else
  fail "main.tf KHÔNG có precondition block"
fi

if grep -Eq '^[[:space:]]*postcondition[[:space:]]*\{' "${MAIN_FILE}"; then
  pass "main.tf có postcondition block"
else
  fail "main.tf KHÔNG có postcondition block"
fi

if grep -Eq '^[[:space:]]*check[[:space:]]+"' "${MAIN_FILE}"; then
  pass "main.tf có top-level check {} block"
else
  fail "main.tf KHÔNG có top-level check {} block"
fi

# --- 5. apply succeeded (state file present) --------------------------------
STATE_FILE="${WORK_DIR}/terraform.tfstate"
if [ ! -f "${STATE_FILE}" ]; then
  fail "chưa có terraform.tfstate — bạn đã 'terraform apply' chưa?"
else
  pass "terraform.tfstate tồn tại"

  STATE_LIST=$(terraform -chdir="${WORK_DIR}" state list 2>/dev/null || echo "")
  for addr in 'docker_image.nginx' 'docker_container.app[0]' 'docker_container.app[1]'; do
    if echo "${STATE_LIST}" | grep -qxF "${addr}"; then
      pass "state có ${addr}"
    else
      fail "state thiếu ${addr}"
    fi
  done
fi

# --- 6. live containers + correct ports -------------------------------------
if ! command -v docker >/dev/null 2>&1; then
  fail "docker CLI không có"
else
  for spec in "tflab-11-1:8221" "tflab-11-2:8222"; do
    cname="${spec%%:*}"
    expected_port="${spec##*:}"
    if docker inspect -f '{{.State.Running}}' "${cname}" 2>/dev/null | grep -q true; then
      pass "container ${cname} đang chạy"
    else
      fail "container ${cname} không chạy"
    fi
    actual_port=$(docker inspect -f '{{ (index (index .NetworkSettings.Ports "80/tcp") 0).HostPort }}' "${cname}" 2>/dev/null || echo "")
    if [ "${actual_port}" = "${expected_port}" ]; then
      pass "${cname} bind port ${expected_port}"
    else
      fail "${cname} bind port '${actual_port}' (mong đợi '${expected_port}')"
    fi
  done
fi

# --- 7. outputs --------------------------------------------------------------
if [ -f "${STATE_FILE}" ] && command -v jq >/dev/null 2>&1; then
  NAMES_JSON=$(terraform -chdir="${WORK_DIR}" output -json names 2>/dev/null || echo "[]")
  NAMES_JOINED=$(echo "${NAMES_JSON}" | jq -r 'join(",")')
  if [ "${NAMES_JOINED}" = "tflab-11-1,tflab-11-2" ]; then
    pass "output names = [tflab-11-1, tflab-11-2]"
  else
    fail "output names = '${NAMES_JOINED}' (mong đợi 'tflab-11-1,tflab-11-2')"
  fi

  URLS_JSON=$(terraform -chdir="${WORK_DIR}" output -json urls 2>/dev/null || echo "[]")
  URLS_JOINED=$(echo "${URLS_JSON}" | jq -r 'join(",")')
  if [ "${URLS_JOINED}" = "http://localhost:8221,http://localhost:8222" ]; then
    pass "output urls đúng giá trị"
  else
    fail "output urls = '${URLS_JOINED}' (mong đợi 'http://localhost:8221,http://localhost:8222')"
  fi
fi

# --- 8. idempotency ----------------------------------------------------------
if [ -f "${STATE_FILE}" ]; then
  PLAN_OUT=$(terraform -chdir="${WORK_DIR}" plan -detailed-exitcode -no-color -input=false 2>/dev/null; echo "EXIT:$?")
  PLAN_EXIT=$(echo "${PLAN_OUT}" | tail -1 | sed 's/^EXIT://')
  if [ "${PLAN_EXIT}" = "0" ]; then
    pass "terraform plan = 0 changes (idempotent)"
  elif [ "${PLAN_EXIT}" = "2" ]; then
    fail "terraform plan còn diff — config chưa khớp state"
  else
    fail "terraform plan lỗi (exit ${PLAN_EXIT})"
  fi
fi

# --- 9. negative validation test — out-of-range port must FAIL --------------
NEG_OUT=$(terraform -chdir="${WORK_DIR}" plan -no-color -input=false -var "base_port=80" 2>&1 || true)
if echo "${NEG_OUT}" | grep -qi "Invalid value for variable\|validation"; then
  pass "validation chặn base_port ngoài [8000, 9999]"
else
  fail "validation KHÔNG chặn base_port=80 — variable validation chưa đầy đủ"
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
