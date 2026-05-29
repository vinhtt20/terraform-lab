#!/usr/bin/env bash
# verify.sh — Lab 13 grader (policy as code, CI/CD gating)
# Compatible with bash 3.2 (macOS default).

set -euo pipefail

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR="${LAB_DIR}/starter"
PASS=0
FAIL=0

pass() { echo "  ✅ $1"; PASS=$((PASS+1)); }
fail() { echo "  ❌ $1"; FAIL=$((FAIL+1)); }

echo "▶ Lab 13 — verify"

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

# --- 3. policy files exist with `deny` rules --------------------------------
POL_DIR="${WORK_DIR}/policies"
if [ -d "${POL_DIR}" ]; then
  pass "policies/ directory tồn tại"
else
  fail "policies/ directory KHÔNG tồn tại"
fi

for f in no_latest_tag require_owner_label; do
  POL="${POL_DIR}/${f}.rego"
  if [ -f "${POL}" ]; then
    pass "policy ${f}.rego tồn tại"
    if grep -Eq '^[[:space:]]*deny\[' "${POL}"; then
      pass "${f}.rego có rule 'deny[...]'"
    else
      fail "${f}.rego KHÔNG có rule 'deny[...]' (chỉ có TODO?)"
    fi
  else
    fail "policy ${f}.rego KHÔNG tồn tại"
  fi
done

# --- 4. ci-check.sh exists + executable -------------------------------------
CI_SCRIPT="${WORK_DIR}/ci-check.sh"
if [ -f "${CI_SCRIPT}" ]; then
  pass "ci-check.sh tồn tại"
  if [ -x "${CI_SCRIPT}" ]; then
    pass "ci-check.sh có quyền execute"
  else
    echo "  ℹ️  ci-check.sh không có +x — bạn vẫn có thể chạy 'bash ci-check.sh'."
  fi
else
  fail "ci-check.sh KHÔNG tồn tại"
fi

# --- 5. conftest gating — pass on compliant config; fail on violation -------
if ! command -v conftest >/dev/null 2>&1; then
  echo "  ℹ️  conftest CLI chưa cài. Cài: 'brew install conftest'. Skip policy run."
else
  pass "conftest CLI có"

  # Positive: compliant config must pass.
  GATE_OUT=$(bash "${CI_SCRIPT}" 2>&1 || true)
  if echo "${GATE_OUT}" | grep -q "0 failures"; then
    pass "ci-check.sh trên config sạch: 0 violations"
  elif echo "${GATE_OUT}" | grep -qiE "deny|violation|failure"; then
    fail "ci-check.sh trên config sạch BÁO violation (policy quá nghiêm?)"
    echo "${GATE_OUT}" | tail -10 | sed 's/^/      /'
  else
    fail "ci-check.sh exit không-zero không xác định"
    echo "${GATE_OUT}" | tail -10 | sed 's/^/      /'
  fi

  # Negative: inject :latest violation, expect ci-check to fail.
  TMP_OVERRIDE="${WORK_DIR}/_test_violation.tf"
  cat >"${TMP_OVERRIDE}" <<'EOF'
# Temporary file injected by verify.sh — auto-removed on exit.
resource "docker_image" "violation" {
  name         = "alpine:latest"
  keep_locally = true
}
EOF
  trap 'rm -f "${TMP_OVERRIDE}"' EXIT
  NEG_OUT=$(bash "${CI_SCRIPT}" 2>&1 || true)
  if echo "${NEG_OUT}" | grep -qE ':latest|no explicit tag'; then
    pass "ci-check.sh chặn :latest violation đúng cách"
  else
    fail "ci-check.sh KHÔNG chặn :latest — policy chưa hoạt động đầy đủ"
    echo "${NEG_OUT}" | tail -10 | sed 's/^/      /'
  fi
  rm -f "${TMP_OVERRIDE}"
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
