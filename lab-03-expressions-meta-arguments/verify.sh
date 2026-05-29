#!/usr/bin/env bash
# verify.sh — Lab 03 grader
# Compatible with bash 3.2 (macOS default): no associative arrays, no mapfile.

set -euo pipefail

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR="${LAB_DIR}/starter"
PASS=0
FAIL=0

pass() { echo "  ✅ $1"; PASS=$((PASS+1)); }
fail() { echo "  ❌ $1"; FAIL=$((FAIL+1)); }

echo "▶ Lab 03 — verify"

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

  # Expected addresses (default services map has alpha/bravo/charlie).
  EXPECTED='docker_image.nginx
docker_container.app["alpha"]
docker_container.app["bravo"]
docker_container.app["charlie"]
local_file.html["alpha"]
local_file.html["bravo"]
local_file.html["charlie"]'

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

  # urls output is map with 3 entries.
  URLS_JSON=$(terraform -chdir="${WORK_DIR}" output -json urls 2>/dev/null || echo "{}")
  URLS_LEN=$(echo "${URLS_JSON}" | jq 'length' 2>/dev/null || echo "0")
  if [ "${URLS_LEN}" = "3" ]; then
    pass "output 'urls' có 3 entry"
  else
    fail "output 'urls' có ${URLS_LEN} entry (mong đợi 3)"
  fi

  # Each url must contain http://localhost:<port>
  BAD_URLS=$(echo "${URLS_JSON}" | jq -r '[.[] | select(test("^http://localhost:[0-9]+$") | not)] | length' 2>/dev/null || echo "1")
  if [ "${BAD_URLS}" = "0" ]; then
    pass "mọi url khớp pattern http://localhost:<port>"
  else
    fail "có ${BAD_URLS} url không khớp pattern"
  fi

  # service_count
  SCNT=$(terraform -chdir="${WORK_DIR}" output -raw service_count 2>/dev/null || echo "0")
  if [ "${SCNT}" = "3" ]; then
    pass "output 'service_count' = 3"
  else
    fail "output 'service_count' = ${SCNT} (mong đợi 3)"
  fi

  # HTML files exist and contain service name.
  HTML_OK=1
  for svc in alpha bravo charlie; do
    HTML_FILE="${WORK_DIR}/html/${svc}.html"
    if [ ! -f "${HTML_FILE}" ]; then
      fail "thiếu file ${HTML_FILE}"
      HTML_OK=0
    else
      if grep -q "${svc}" "${HTML_FILE}"; then
        pass "html/${svc}.html chứa tên service '${svc}'"
      else
        fail "html/${svc}.html không chứa tên service '${svc}'"
        HTML_OK=0
      fi
    fi
  done

  # Cross-check Docker if available.
  if command -v docker >/dev/null 2>&1; then
    for svc in alpha bravo charlie; do
      if docker inspect -f '{{.State.Running}}' "tflab-03-${svc}" 2>/dev/null | grep -q true; then
        pass "container tflab-03-${svc} đang chạy"
      else
        fail "container tflab-03-${svc} không chạy"
      fi
    done

    # Curl one of them to confirm the templated HTML is served.
    if command -v curl >/dev/null 2>&1; then
      ALPHA_URL=$(echo "${URLS_JSON}" | jq -r '.alpha // empty' 2>/dev/null || echo "")
      if [ -n "${ALPHA_URL}" ]; then
        BODY=$(curl -s --max-time 5 "${ALPHA_URL}" || echo "")
        if echo "${BODY}" | grep -qi 'alpha'; then
          pass "curl ${ALPHA_URL} trả về nội dung chứa 'alpha'"
        else
          fail "curl ${ALPHA_URL} không trả về nội dung mong đợi"
        fi
      fi
    fi
  fi

  # Idempotency: second plan must show 0 changes.
  PLAN_OUT=$(terraform -chdir="${WORK_DIR}" plan -detailed-exitcode -no-color -input=false 2>/dev/null; echo "EXIT:$?")
  PLAN_EXIT=$(echo "${PLAN_OUT}" | tail -1 | sed 's/^EXIT://')
  if [ "${PLAN_EXIT}" = "0" ]; then
    pass "terraform plan lần 2 báo 0 changes (idempotent)"
  elif [ "${PLAN_EXIT}" = "2" ]; then
    fail "terraform plan lần 2 vẫn có changes — không idempotent (kiểm tra ignore_changes cho rendered_at)"
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
