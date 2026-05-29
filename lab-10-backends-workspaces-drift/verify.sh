#!/usr/bin/env bash
# verify.sh — Lab 10 grader (backends, workspaces, drift)
# Compatible with bash 3.2 (macOS default).

set -euo pipefail

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR="${LAB_DIR}/starter"
PASS=0
FAIL=0

pass() { echo "  ✅ $1"; PASS=$((PASS+1)); }
fail() { echo "  ❌ $1"; FAIL=$((FAIL+1)); }

echo "▶ Lab 10 — verify"

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

# --- 3. explicit local backend declaration -----------------------------------
if grep -Eq '^[[:space:]]*backend[[:space:]]+"local"' "${WORK_DIR}/versions.tf"; then
  pass "versions.tf có 'backend \"local\" {}' (explicit)"
else
  fail "versions.tf KHÔNG có 'backend \"local\" {}' — yêu cầu khai báo explicit"
fi

# --- 4. uses terraform.workspace --------------------------------------------
if grep -Eq 'terraform\.workspace' "${WORK_DIR}/main.tf"; then
  pass "main.tf tham chiếu 'terraform.workspace'"
else
  fail "main.tf KHÔNG tham chiếu 'terraform.workspace'"
fi

# --- 5. workspaces exist ----------------------------------------------------
ORIGINAL_WS=$(terraform -chdir="${WORK_DIR}" workspace show 2>/dev/null || echo "default")
WS_LIST=$(terraform -chdir="${WORK_DIR}" workspace list 2>/dev/null | tr -d '*' | awk '{$1=$1};1')

for ws in dev prod; do
  if echo "${WS_LIST}" | grep -qxF "${ws}"; then
    pass "workspace '${ws}' tồn tại"
  else
    fail "workspace '${ws}' không tồn tại — chạy 'terraform workspace new ${ws}'"
  fi
done

# --- 6. state files for each workspace --------------------------------------
for ws in dev prod; do
  if [ -f "${WORK_DIR}/terraform.tfstate.d/${ws}/terraform.tfstate" ]; then
    pass "state file cho workspace '${ws}' tồn tại"
  else
    fail "state file cho workspace '${ws}' KHÔNG tồn tại — bạn đã apply ở workspace này chưa?"
  fi
done

# --- 7. live containers per workspace ----------------------------------------
if ! command -v docker >/dev/null 2>&1; then
  fail "docker CLI không có"
else
  for name in tflab-10-dev-1 tflab-10-prod-1 tflab-10-prod-2; do
    if docker inspect -f '{{.State.Running}}' "${name}" 2>/dev/null | grep -q true; then
      pass "container ${name} đang chạy"
    else
      fail "container ${name} không chạy"
    fi
  done

  # Workspace label check — container must carry tflab.workspace=<env>.
  for spec in "tflab-10-dev-1:dev" "tflab-10-prod-1:prod" "tflab-10-prod-2:prod"; do
    cname="${spec%%:*}"
    expected_label="${spec##*:}"
    actual_label=$(docker inspect -f '{{ index .Config.Labels "tflab.workspace" }}' "${cname}" 2>/dev/null || echo "")
    if [ "${actual_label}" = "${expected_label}" ]; then
      pass "${cname} có label tflab.workspace=${expected_label}"
    else
      fail "${cname} label tflab.workspace='${actual_label}' (mong đợi '${expected_label}')"
    fi
  done
fi

# --- 8. per-workspace idempotency + output checks ----------------------------
check_workspace() {
  local ws="$1"
  local expected_url_count="$2"
  local expected_first_port="$3"

  terraform -chdir="${WORK_DIR}" workspace select "${ws}" >/dev/null 2>&1

  # Idempotency
  PLAN_OUT=$(terraform -chdir="${WORK_DIR}" plan -detailed-exitcode -no-color -input=false 2>/dev/null; echo "EXIT:$?")
  PLAN_EXIT=$(echo "${PLAN_OUT}" | tail -1 | sed 's/^EXIT://')
  if [ "${PLAN_EXIT}" = "0" ]; then
    pass "[${ws}] plan = 0 changes (idempotent)"
  elif [ "${PLAN_EXIT}" = "2" ]; then
    fail "[${ws}] plan vẫn có diff — drift hoặc config chưa khớp state"
  else
    fail "[${ws}] plan lỗi (exit ${PLAN_EXIT})"
  fi

  # workspace_name output
  WS_NAME=$(terraform -chdir="${WORK_DIR}" output -raw workspace_name 2>/dev/null || echo "")
  if [ "${WS_NAME}" = "${ws}" ]; then
    pass "[${ws}] output workspace_name = '${ws}'"
  else
    fail "[${ws}] output workspace_name = '${WS_NAME}' (mong đợi '${ws}')"
  fi

  # urls output (list)
  if command -v jq >/dev/null 2>&1; then
    URLS_JSON=$(terraform -chdir="${WORK_DIR}" output -json urls 2>/dev/null || echo "[]")
    URL_COUNT=$(echo "${URLS_JSON}" | jq 'length' 2>/dev/null || echo "0")
    if [ "${URL_COUNT}" = "${expected_url_count}" ]; then
      pass "[${ws}] urls có ${expected_url_count} phần tử"
    else
      fail "[${ws}] urls có ${URL_COUNT} phần tử (mong đợi ${expected_url_count})"
    fi
    FIRST_URL=$(echo "${URLS_JSON}" | jq -r '.[0] // empty')
    EXPECTED_FIRST="http://localhost:${expected_first_port}"
    if [ "${FIRST_URL}" = "${EXPECTED_FIRST}" ]; then
      pass "[${ws}] urls[0] = ${EXPECTED_FIRST}"
    else
      fail "[${ws}] urls[0] = '${FIRST_URL}' (mong đợi '${EXPECTED_FIRST}')"
    fi
  fi
}

if echo "${WS_LIST}" | grep -qxF "dev"; then
  check_workspace dev 1 8201
fi
if echo "${WS_LIST}" | grep -qxF "prod"; then
  check_workspace prod 2 8202
fi

# Restore original workspace
terraform -chdir="${WORK_DIR}" workspace select "${ORIGINAL_WS}" >/dev/null 2>&1 || true

echo
echo "Kết quả: ${PASS} pass, ${FAIL} fail"
if [ ${FAIL} -eq 0 ]; then
  echo "PASS"
  exit 0
else
  echo "FAIL"
  exit 1
fi
