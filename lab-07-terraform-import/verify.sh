#!/usr/bin/env bash
# verify.sh — Lab 07 grader
# Compatible with bash 3.2 (macOS default): no associative arrays, no mapfile.

set -euo pipefail

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR="${LAB_DIR}/starter"
PASS=0
FAIL=0

pass() { echo "  ✅ $1"; PASS=$((PASS+1)); }
fail() { echo "  ❌ $1"; FAIL=$((FAIL+1)); }

echo "▶ Lab 07 — verify"

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

# --- 3. setup must have run — legacy resources exist in Docker --------------
if ! command -v docker >/dev/null 2>&1; then
  fail "docker CLI không có; bạn cần Docker để chạy lab này"
else
  if docker container inspect tflab-07-legacy-app >/dev/null 2>&1; then
    pass "container tflab-07-legacy-app tồn tại (setup.sh đã chạy)"
  else
    fail "container tflab-07-legacy-app không tồn tại — chạy 'bash setup.sh' trước"
  fi
  if docker volume inspect tflab-07-legacy-data >/dev/null 2>&1; then
    pass "volume tflab-07-legacy-data tồn tại"
  else
    fail "volume tflab-07-legacy-data không tồn tại"
  fi
fi

# --- 4. state assertions ----------------------------------------------------
STATE_FILE="${WORK_DIR}/terraform.tfstate"
if [ ! -f "${STATE_FILE}" ]; then
  fail "chưa có terraform.tfstate — bạn đã 'terraform import' + 'terraform apply' chưa?"
else
  STATE_LIST=$(terraform -chdir="${WORK_DIR}" state list 2>/dev/null || echo "")

  EXPECTED='docker_image.nginx
docker_volume.legacy_data
docker_container.legacy_app'

  while IFS= read -r addr; do
    [ -z "${addr}" ] && continue
    if echo "${STATE_LIST}" | grep -qxF "${addr}"; then
      pass "state có ${addr}"
    else
      fail "state thiếu ${addr} (đã 'terraform import' chưa?)"
    fi
  done <<EOF
${EXPECTED}
EOF

  # ---- container ID in state matches the live Docker container --------------
  if command -v docker >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
    LIVE_ID=$(docker inspect --format '{{.Id}}' tflab-07-legacy-app 2>/dev/null || echo "")
    STATE_ID=$(terraform -chdir="${WORK_DIR}" state show docker_container.legacy_app 2>/dev/null \
                  | awk '/^[[:space:]]*id[[:space:]]*=/ {gsub(/[",]/,"",$3); print $3; exit}')
    if [ -n "${LIVE_ID}" ] && [ -n "${STATE_ID}" ]; then
      # state may store a truncated form on some provider versions; compare prefix
      case "${LIVE_ID}" in
        ${STATE_ID}*) pass "state.container.id khớp Docker live ID";;
        *) case "${STATE_ID}" in
             ${LIVE_ID}*) pass "state.container.id khớp Docker live ID";;
             *) fail "state.container.id (${STATE_ID}) KHÔNG khớp live (${LIVE_ID})";;
           esac;;
      esac
    fi
  fi

  # ---- outputs ----
  OUT_VOL=$(terraform -chdir="${WORK_DIR}" output -raw volume_name 2>/dev/null || echo "")
  if [ "${OUT_VOL}" = "tflab-07-legacy-data" ]; then
    pass "output volume_name = tflab-07-legacy-data"
  else
    fail "output volume_name khác mong đợi (got: '${OUT_VOL}')"
  fi

  OUT_URL=$(terraform -chdir="${WORK_DIR}" output -raw url 2>/dev/null || echo "")
  if [ "${OUT_URL}" = "http://localhost:8110" ]; then
    pass "output url = http://localhost:8110"
  else
    fail "output url khác mong đợi (got: '${OUT_URL}')"
  fi

  OUT_CID=$(terraform -chdir="${WORK_DIR}" output -raw container_id 2>/dev/null || echo "")
  if [ -n "${OUT_CID}" ]; then
    pass "output container_id có giá trị"
  else
    fail "output container_id rỗng"
  fi

  # ---- container still running (NOT destroyed by Terraform) ----
  if command -v docker >/dev/null 2>&1; then
    if docker inspect -f '{{.State.Running}}' tflab-07-legacy-app 2>/dev/null | grep -q true; then
      pass "container tflab-07-legacy-app vẫn đang chạy (không bị destroy/recreate)"
    else
      fail "container tflab-07-legacy-app KHÔNG chạy — có thể bạn đã apply khi plan còn diff"
    fi
  fi

  # ---- idempotency: plan must be zero changes ----
  PLAN_OUT=$(terraform -chdir="${WORK_DIR}" plan -detailed-exitcode -no-color -input=false 2>/dev/null; echo "EXIT:$?")
  PLAN_EXIT=$(echo "${PLAN_OUT}" | tail -1 | sed 's/^EXIT://')
  if [ "${PLAN_EXIT}" = "0" ]; then
    pass "terraform plan = 0 changes (config khớp state)"
  elif [ "${PLAN_EXIT}" = "2" ]; then
    fail "terraform plan VẪN có changes — config chưa khớp live (đọc state show + tinh chỉnh)"
  else
    fail "terraform plan lỗi (exit ${PLAN_EXIT})"
  fi

  # ---- plan with -refresh=false: even without refresh, config must equal state
  PLAN_NR=$(terraform -chdir="${WORK_DIR}" plan -detailed-exitcode -refresh=false -no-color -input=false 2>/dev/null; echo "EXIT:$?")
  PLAN_NR_EXIT=$(echo "${PLAN_NR}" | tail -1 | sed 's/^EXIT://')
  if [ "${PLAN_NR_EXIT}" = "0" ]; then
    pass "terraform plan -refresh=false = 0 changes (config thực sự đại diện state)"
  elif [ "${PLAN_NR_EXIT}" = "2" ]; then
    fail "plan -refresh=false có diff — config dựa vào refresh để 'che' diff"
  else
    fail "terraform plan -refresh=false lỗi (exit ${PLAN_NR_EXIT})"
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
