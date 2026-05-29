#!/usr/bin/env bash
# verify.sh — Lab 14 capstone grader (modules, validation, test, policy).
# Compatible with bash 3.2 (macOS default).

set -euo pipefail

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR="${LAB_DIR}/starter"
PASS=0
FAIL=0

pass() { echo "  ✅ $1"; PASS=$((PASS+1)); }
fail() { echo "  ❌ $1"; FAIL=$((FAIL+1)); }

echo "▶ Lab 14 — capstone verify"

# --- 1. fmt + validate ------------------------------------------------------
if terraform -chdir="${WORK_DIR}" fmt -check -recursive >/dev/null 2>&1; then
  pass "terraform fmt sạch (recursive)"
else
  fail "terraform fmt phát hiện file chưa format"
fi

if [ ! -d "${WORK_DIR}/.terraform" ]; then
  terraform -chdir="${WORK_DIR}" init -input=false -no-color >/dev/null 2>&1 || fail "terraform init thất bại"
fi

if terraform -chdir="${WORK_DIR}" validate -no-color >/dev/null 2>&1; then
  pass "terraform validate pass"
else
  fail "terraform validate thất bại"
fi

# --- 2. structure -----------------------------------------------------------
MOD_DIR="${WORK_DIR}/modules/web_service"
for f in versions.tf variables.tf main.tf outputs.tf; do
  if [ -f "${MOD_DIR}/${f}" ]; then
    pass "module web_service có ${f}"
  else
    fail "module web_service thiếu ${f}"
  fi
done

# --- 3. root main.tf uses module + check ------------------------------------
if grep -Eq '^[[:space:]]*module[[:space:]]+"web"' "${WORK_DIR}/main.tf"; then
  pass "root main.tf instantiate module 'web'"
else
  fail "root main.tf KHÔNG instantiate module 'web' (xem TODO)"
fi

if grep -Eq 'for_each[[:space:]]*=[[:space:]]*var\.services' "${WORK_DIR}/main.tf"; then
  pass "module 'web' dùng for_each = var.services"
else
  fail "module 'web' chưa dùng for_each = var.services"
fi

if grep -Eq '^[[:space:]]*check[[:space:]]+"' "${WORK_DIR}/main.tf"; then
  pass "root main.tf có top-level check {} block"
else
  fail "root main.tf KHÔNG có check {} block"
fi

# --- 4. ephemeral output in module ------------------------------------------
if grep -Eq 'ephemeral[[:space:]]*=[[:space:]]*true' "${MOD_DIR}/outputs.tf"; then
  pass "module web_service có ephemeral output"
else
  fail "module web_service KHÔNG có ephemeral output"
fi

# --- 5. policy file with deny rule ------------------------------------------
POL="${WORK_DIR}/policies/require_owner_label.rego"
if [ -f "${POL}" ] && grep -Eq '^[[:space:]]*deny\[' "${POL}"; then
  pass "policy require_owner_label.rego có deny[...]"
else
  fail "policy require_owner_label.rego thiếu deny[...] rule"
fi

# --- 6. test file -----------------------------------------------------------
TEST_FILE="${WORK_DIR}/tests/basic.tftest.hcl"
if [ -f "${TEST_FILE}" ]; then
  pass "tests/basic.tftest.hcl tồn tại"
else
  fail "tests/basic.tftest.hcl KHÔNG tồn tại"
fi

# Detect existing state. `terraform state list` exits non-zero with no init
# OR no state, so guard with `|| true`. `pipefail` + `||` can concatenate
# fallback values — keep this two-step instead of piping.
STATE_LIST=$(terraform -chdir="${WORK_DIR}" state list 2>/dev/null || true)
if [ -z "${STATE_LIST}" ]; then
  HAVE_STATE_RESOURCES="0"
else
  HAVE_STATE_RESOURCES=$(printf '%s' "${STATE_LIST}" | grep -cE '.' || echo "0")
fi

# --- 7. terraform test (clean state only) -----------------------------------
if [ -f "${TEST_FILE}" ]; then
  if [ "${HAVE_STATE_RESOURCES}" != "0" ]; then
    echo "  ℹ️  Skip 'terraform test' (state có ${HAVE_STATE_RESOURCES} resources). Destroy rồi verify lại."
  else
    TEST_OUT=$(terraform -chdir="${WORK_DIR}" test -no-color 2>&1 || true)
    if echo "${TEST_OUT}" | grep -q "Success!"; then
      pass "terraform test pass"
      echo "${TEST_OUT}" | grep -E '^  run|^Success!|^Failure!' | sed 's/^/      /'
    else
      fail "terraform test FAIL"
      echo "${TEST_OUT}" | tail -15 | sed 's/^/      /'
    fi
  fi
fi

# --- 8. ci-check.sh ---------------------------------------------------------
if [ -f "${WORK_DIR}/ci-check.sh" ]; then
  pass "ci-check.sh tồn tại"
else
  fail "ci-check.sh KHÔNG tồn tại"
fi

# --- 9. state assertions (only if state present) ----------------------------
if [ "${HAVE_STATE_RESOURCES}" != "0" ]; then
  STATE_LIST=$(terraform -chdir="${WORK_DIR}" state list 2>/dev/null || echo "")
  for addr in 'module.web["api"].docker_container.this' 'module.web["web"].docker_container.this'; do
    if echo "${STATE_LIST}" | grep -qxF "${addr}"; then
      pass "state có ${addr}"
    else
      fail "state thiếu ${addr}"
    fi
  done
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
