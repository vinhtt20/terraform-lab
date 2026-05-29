#!/usr/bin/env bash
# verify.sh — Lab 02 grader
# Compatible with bash 3.2 (macOS default): no associative arrays, no mapfile.

set -euo pipefail

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR="${LAB_DIR}/starter"
PASS=0
FAIL=0

pass() { echo "  ✅ $1"; PASS=$((PASS+1)); }
fail() { echo "  ❌ $1"; FAIL=$((FAIL+1)); }

echo "▶ Lab 02 — verify"

# --- 1. fmt -----------------------------------------------------------------
if terraform -chdir="${WORK_DIR}" fmt -check -recursive >/dev/null 2>&1; then
  pass "terraform fmt sạch"
else
  fail "terraform fmt phát hiện file chưa format (chạy 'terraform fmt' trong starter/)"
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

  if echo "${STATE_LIST}" | grep -qx 'docker_image.app'; then
    pass "state có docker_image.app"
  else
    fail "state thiếu docker_image.app"
  fi

  if echo "${STATE_LIST}" | grep -qE '^docker_container\.app\['; then
    pass "state có ít nhất 1 docker_container.app[...]"
  else
    fail "state thiếu docker_container.app[...] — đã dùng for_each chưa?"
  fi

  # Discover service_name from any container name in state
  SAMPLE_NAME=$(terraform -chdir="${WORK_DIR}" output -json container_names 2>/dev/null \
                  | jq -r '.[0] // empty' 2>/dev/null || echo "")
  SERVICE=""
  if [ -n "${SAMPLE_NAME}" ]; then
    # Extract <service> from "tflab-02-<service>-<idx>"
    SERVICE=$(echo "${SAMPLE_NAME}" | sed -E 's/^tflab-02-(.+)-[0-9]+$/\1/')
  fi
  if [ -n "${SERVICE}" ]; then
    pass "container_names theo pattern tflab-02-${SERVICE}-<idx>"
  else
    fail "container_names không khớp pattern tflab-02-<service>-<idx>"
  fi

  # Verify every container name matches the pattern.
  NAMES_JSON=$(terraform -chdir="${WORK_DIR}" output -json container_names 2>/dev/null || echo "[]")
  BAD=$(echo "${NAMES_JSON}" | jq -r --arg svc "${SERVICE}" \
        '[.[] | select(test("^tflab-02-" + $svc + "-[0-9]+$") | not)] | length' 2>/dev/null || echo "1")
  if [ "${BAD}" = "0" ]; then
    pass "mọi container_names khớp regex"
  else
    fail "có ${BAD} container_names không khớp pattern"
  fi

  # ports length == container_names length
  NLEN=$(echo "${NAMES_JSON}" | jq 'length' 2>/dev/null || echo "0")
  PORTS_JSON=$(terraform -chdir="${WORK_DIR}" output -json ports 2>/dev/null || echo "[]")
  PLEN=$(echo "${PORTS_JSON}" | jq 'length' 2>/dev/null || echo "0")
  if [ "${NLEN}" = "${PLEN}" ] && [ "${NLEN}" -gt 0 ]; then
    pass "số ports (${PLEN}) khớp số replicas (${NLEN})"
  else
    fail "số ports (${PLEN}) khác số container_names (${NLEN})"
  fi

  # password output should print <sensitive> without -json/-raw.
  PWD_NON_RAW=$(terraform -chdir="${WORK_DIR}" output password 2>&1 || true)
  if echo "${PWD_NON_RAW}" | grep -q 'sensitive'; then
    pass "output 'password' đánh dấu sensitive (in '<sensitive>')"
  else
    fail "output 'password' không sensitive (in '${PWD_NON_RAW}')"
  fi

  # summary.json file existence + valid JSON + required keys
  SUMMARY_PATH=$(terraform -chdir="${WORK_DIR}" output -raw summary_path 2>/dev/null || echo "")
  if [ -z "${SUMMARY_PATH}" ]; then
    fail "output 'summary_path' rỗng"
  else
    # Resolve relative paths against starter/
    case "${SUMMARY_PATH}" in
      /*) ABS_SUMMARY="${SUMMARY_PATH}" ;;
      *)  ABS_SUMMARY="${WORK_DIR}/${SUMMARY_PATH}" ;;
    esac
    if [ -f "${ABS_SUMMARY}" ]; then
      pass "summary file tồn tại: ${ABS_SUMMARY}"
      if jq -e . "${ABS_SUMMARY}" >/dev/null 2>&1; then
        pass "summary file là JSON hợp lệ"
      else
        fail "summary file không phải JSON hợp lệ"
      fi
      HAS_KEYS=$(jq -r 'has("names") and has("ports") and has("labels")' "${ABS_SUMMARY}" 2>/dev/null || echo "false")
      if [ "${HAS_KEYS}" = "true" ]; then
        pass "summary có đủ keys: names, ports, labels"
      else
        fail "summary thiếu 1 trong các keys: names/ports/labels"
      fi
      # Make sure password is NOT leaked into the summary.
      if jq -r 'keys[]' "${ABS_SUMMARY}" 2>/dev/null | grep -qi 'password'; then
        fail "summary file CÓ key chứa 'password' — đừng leak secret!"
      else
        pass "summary file không leak password"
      fi
    else
      fail "summary file không tồn tại tại ${ABS_SUMMARY}"
    fi
  fi

  # Idempotency: second plan must show no changes.
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
