#!/usr/bin/env bash
# verify.sh — Lab 12 grader (testing, replace_triggered_by, terraform_data)
# Compatible with bash 3.2 (macOS default).

set -euo pipefail

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR="${LAB_DIR}/starter"
PASS=0
FAIL=0

pass() { echo "  ✅ $1"; PASS=$((PASS+1)); }
fail() { echo "  ❌ $1"; FAIL=$((FAIL+1)); }

echo "▶ Lab 12 — verify"

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

# --- 3. required syntax in main.tf ------------------------------------------
MAIN_FILE="${WORK_DIR}/main.tf"

if grep -Eq '^[[:space:]]*resource[[:space:]]+"terraform_data"' "${MAIN_FILE}"; then
  pass "main.tf có resource terraform_data"
else
  fail "main.tf KHÔNG có resource terraform_data — bắt buộc cho lab này"
fi

if grep -Eq 'replace_triggered_by[[:space:]]*=' "${MAIN_FILE}"; then
  pass "main.tf có replace_triggered_by"
else
  fail "main.tf KHÔNG có replace_triggered_by"
fi

# --- 4. test file present + passes ------------------------------------------
TEST_FILE="${WORK_DIR}/tests/basic.tftest.hcl"
if [ -f "${TEST_FILE}" ]; then
  pass "tests/basic.tftest.hcl tồn tại"
else
  fail "tests/basic.tftest.hcl KHÔNG tồn tại"
fi

# `terraform test` creates real containers; it conflicts with an existing
# apply-state of the same module. Only run it when the workspace is clean.
HAVE_STATE_RESOURCES=$(terraform -chdir="${WORK_DIR}" state list 2>/dev/null | wc -l | tr -d ' ' || echo "0")
if [ -f "${TEST_FILE}" ]; then
  if [ "${HAVE_STATE_RESOURCES}" != "0" ]; then
    echo "  ℹ️  Skip 'terraform test' (state already has ${HAVE_STATE_RESOURCES} resources). Chạy 'terraform destroy' rồi 'bash verify.sh' lại để chạy test."
  else
    TEST_OUT=$(terraform -chdir="${WORK_DIR}" test -no-color 2>&1 || true)
    if echo "${TEST_OUT}" | grep -q "Success!"; then
      pass "terraform test pass (xem chi tiết bên dưới)"
      echo "${TEST_OUT}" | grep -E '^  run|^Success!|^Failure!' | sed 's/^/      /'
    else
      fail "terraform test FAIL"
      echo "${TEST_OUT}" | tail -20 | sed 's/^/      /'
    fi
  fi
fi

# --- 5. apply + idempotent check (only if state already present) ------------
if [ "${HAVE_STATE_RESOURCES}" != "0" ]; then
  STATE_LIST=$(terraform -chdir="${WORK_DIR}" state list 2>/dev/null || echo "")
  for addr in 'docker_image.nginx' 'docker_container.app' 'terraform_data.rotation'; do
    if echo "${STATE_LIST}" | grep -qxF "${addr}"; then
      pass "state có ${addr}"
    else
      fail "state thiếu ${addr}"
    fi
  done

  # Idempotency
  PLAN_OUT=$(terraform -chdir="${WORK_DIR}" plan -detailed-exitcode -no-color -input=false 2>/dev/null; echo "EXIT:$?")
  PLAN_EXIT=$(echo "${PLAN_OUT}" | tail -1 | sed 's/^EXIT://')
  if [ "${PLAN_EXIT}" = "0" ]; then
    pass "terraform plan = 0 changes (idempotent)"
  elif [ "${PLAN_EXIT}" = "2" ]; then
    fail "terraform plan vẫn có changes"
  else
    fail "terraform plan lỗi (exit ${PLAN_EXIT})"
  fi
else
  echo "  ℹ️  Chưa có state — skip state checks (chạy 'terraform apply' để verify đầy đủ)."
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
