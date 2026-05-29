#!/usr/bin/env bash
# verify.sh — Lab 08 grader
# Compatible with bash 3.2 (macOS default): no associative arrays, no mapfile.

set -euo pipefail

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR="${LAB_DIR}/starter"
PASS=0
FAIL=0

pass() { echo "  ✅ $1"; PASS=$((PASS+1)); }
fail() { echo "  ❌ $1"; FAIL=$((FAIL+1)); }

echo "▶ Lab 08 — verify"

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

# --- 3. legacy stack must exist in Docker -----------------------------------
if ! command -v docker >/dev/null 2>&1; then
  fail "docker CLI không có"
else
  for name in tflab-08-app1 tflab-08-app2 tflab-08-app3; do
    if docker container inspect "${name}" >/dev/null 2>&1; then
      pass "container ${name} tồn tại"
    else
      fail "container ${name} không tồn tại — chạy 'bash setup.sh' trước"
    fi
  done
  for vol in tflab-08-data1 tflab-08-data2; do
    if docker volume inspect "${vol}" >/dev/null 2>&1; then
      pass "volume ${vol} tồn tại"
    else
      fail "volume ${vol} không tồn tại"
    fi
  done
  if docker network inspect tflab-08-net >/dev/null 2>&1; then
    pass "network tflab-08-net tồn tại"
  else
    fail "network tflab-08-net không tồn tại"
  fi
fi

# --- 4. state assertions ----------------------------------------------------
STATE_FILE="${WORK_DIR}/terraform.tfstate"
if [ ! -f "${STATE_FILE}" ]; then
  fail "chưa có terraform.tfstate — bạn đã 'terraform apply' chưa?"
else
  STATE_LIST=$(terraform -chdir="${WORK_DIR}" state list 2>/dev/null || echo "")

  EXPECTED='docker_image.nginx
docker_network.main
docker_volume.this["data1"]
docker_volume.this["data2"]
docker_container.app["app1"]
docker_container.app["app2"]
docker_container.app["app3"]'

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

  # ---- live Docker objects survived import (NOT destroyed) ------------------
  if command -v docker >/dev/null 2>&1; then
    for name in tflab-08-app1 tflab-08-app2 tflab-08-app3; do
      if docker inspect -f '{{.State.Running}}' "${name}" 2>/dev/null | grep -q true; then
        pass "container ${name} vẫn đang chạy (không bị recreate)"
      else
        fail "container ${name} không chạy — bạn có thể đã apply khi plan còn diff"
      fi
    done
  fi

  # ---- outputs ----
  if command -v jq >/dev/null 2>&1; then
    URLS_JSON=$(terraform -chdir="${WORK_DIR}" output -json urls 2>/dev/null || echo "{}")
    EXPECTED_PAIRS='app1:8111 app2:8112 app3:8113'
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

    VOLS_JSON=$(terraform -chdir="${WORK_DIR}" output -json volumes 2>/dev/null || echo "[]")
    VOLS_JOINED=$(echo "${VOLS_JSON}" | jq -r 'sort | join(",")' 2>/dev/null || echo "")
    if [ "${VOLS_JOINED}" = "tflab-08-data1,tflab-08-data2" ]; then
      pass "output volumes = [tflab-08-data1, tflab-08-data2]"
    else
      fail "output volumes khác mong đợi (got: '${VOLS_JOINED}')"
    fi
  fi

  NET_ID=$(terraform -chdir="${WORK_DIR}" output -raw network_id 2>/dev/null || echo "")
  if [ -n "${NET_ID}" ]; then
    pass "output network_id có giá trị"
  else
    fail "output network_id rỗng"
  fi

  # ---- idempotency ---------------------------------------------------------
  PLAN_OUT=$(terraform -chdir="${WORK_DIR}" plan -detailed-exitcode -no-color -input=false 2>/dev/null; echo "EXIT:$?")
  PLAN_EXIT=$(echo "${PLAN_OUT}" | tail -1 | sed 's/^EXIT://')
  if [ "${PLAN_EXIT}" = "0" ]; then
    pass "terraform plan lần 2 = 0 changes (idempotent)"
  elif [ "${PLAN_EXIT}" = "2" ]; then
    fail "terraform plan lần 2 vẫn có changes — config chưa khớp state"
  else
    fail "terraform plan lần 2 lỗi (exit ${PLAN_EXIT})"
  fi

  # ---- plan -refresh=false: stronger guarantee ----
  PLAN_NR=$(terraform -chdir="${WORK_DIR}" plan -detailed-exitcode -refresh=false -no-color -input=false 2>/dev/null; echo "EXIT:$?")
  PLAN_NR_EXIT=$(echo "${PLAN_NR}" | tail -1 | sed 's/^EXIT://')
  if [ "${PLAN_NR_EXIT}" = "0" ]; then
    pass "terraform plan -refresh=false = 0 changes"
  elif [ "${PLAN_NR_EXIT}" = "2" ]; then
    fail "plan -refresh=false còn diff — config dựa vào refresh để 'che' diff"
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
