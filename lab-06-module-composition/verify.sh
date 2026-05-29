#!/usr/bin/env bash
# verify.sh — Lab 06 grader
# Compatible with bash 3.2 (macOS default): no associative arrays, no mapfile.

set -euo pipefail

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR="${LAB_DIR}/starter"
NET_MOD="${WORK_DIR}/modules/network"
SVC_MOD="${WORK_DIR}/modules/service"
PASS=0
FAIL=0

pass() { echo "  ✅ $1"; PASS=$((PASS+1)); }
fail() { echo "  ❌ $1"; FAIL=$((FAIL+1)); }

echo "▶ Lab 06 — verify"

# --- 1. fmt -----------------------------------------------------------------
if terraform -chdir="${WORK_DIR}" fmt -check -recursive >/dev/null 2>&1; then
  pass "terraform fmt sạch (recursive)"
else
  fail "terraform fmt phát hiện file chưa format"
fi

# --- 2. init + validate (root) ----------------------------------------------
if [ ! -d "${WORK_DIR}/.terraform" ]; then
  if ! terraform -chdir="${WORK_DIR}" init -input=false -no-color >/dev/null 2>&1; then
    fail "terraform init thất bại"
  fi
fi

if terraform -chdir="${WORK_DIR}" validate -no-color >/dev/null 2>&1; then
  pass "terraform validate (root) pass"
else
  fail "terraform validate (root) thất bại"
fi

# --- 3. module file structure -----------------------------------------------
for d in "${NET_MOD}" "${SVC_MOD}"; do
  mod_name="$(basename "${d}")"
  for f in versions.tf variables.tf main.tf outputs.tf README.md; do
    if [ -f "${d}/${f}" ]; then
      pass "module ${mod_name} có ${f}"
    else
      fail "module ${mod_name} thiếu ${f}"
    fi
  done
done

# --- 4. anti-pattern: child modules must NOT have provider {} blocks --------
for d in "${NET_MOD}" "${SVC_MOD}"; do
  mod_name="$(basename "${d}")"
  if grep -E '^[[:space:]]*provider[[:space:]]+"' "${d}"/*.tf >/dev/null 2>&1; then
    fail "module ${mod_name} có 'provider {}' block — anti-pattern"
  else
    pass "module ${mod_name} KHÔNG có 'provider {}' block"
  fi
done

# --- 5. service module declares configuration_aliases -----------------------
if grep -q 'configuration_aliases' "${SVC_MOD}/versions.tf" 2>/dev/null; then
  pass "module service khai báo configuration_aliases (cho phép alias từ root)"
else
  fail "module service thiếu configuration_aliases trong versions.tf"
fi

# --- 6. independent validate (NETWORK module — service can't because aliases) ----
if [ -d "${NET_MOD}" ]; then
  if (cd "${NET_MOD}" && terraform init -backend=false -input=false -no-color >/dev/null 2>&1 \
                      && terraform validate -no-color >/dev/null 2>&1); then
    pass "module network validate ĐỘC LẬP"
  else
    fail "module network không validate độc lập được"
  fi
fi

# --- 7. state assertions ----------------------------------------------------
STATE_FILE="${WORK_DIR}/terraform.tfstate"
if [ ! -f "${STATE_FILE}" ]; then
  fail "chưa có terraform.tfstate — bạn đã chạy 'terraform apply' chưa?"
else
  STATE_LIST=$(terraform -chdir="${WORK_DIR}" state list 2>/dev/null || echo "")

  # Network module present.
  if echo "${STATE_LIST}" | grep -qE '^module\.network\.docker_network\.'; then
    pass "state có module.network.docker_network.*"
  else
    fail "state thiếu module.network.docker_network.* (đã refactor chưa?)"
  fi

  # Each expected service instance.
  EXPECTED='module.service_east["web"].docker_container.this["0"]
module.service_east["web"].docker_container.this["1"]
module.service_east["worker"].docker_container.this["0"]
module.service_west["api"].docker_container.this["0"]'

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

  # No monolith leftovers at root.
  if echo "${STATE_LIST}" | grep -qE '^docker_(network|container|image)\.'; then
    fail "root state vẫn còn docker_* trực tiếp — chưa refactor xong (phải chuyển hết vào module)"
  else
    pass "root state KHÔNG còn docker_* trực tiếp (đã refactor hoàn toàn)"
  fi

  # ---- container count + names ----
  NAMES_JSON=$(terraform -chdir="${WORK_DIR}" output -json container_names 2>/dev/null || echo "[]")
  NCNT=$(echo "${NAMES_JSON}" | jq 'length' 2>/dev/null || echo "0")
  if [ "${NCNT}" = "4" ]; then
    pass "container_names có đúng 4 phần tử (web×2 + api×1 + worker×1)"
  else
    fail "container_names có ${NCNT} phần tử (mong đợi 4)"
  fi

  # ---- output structure ----
  EAST_JSON=$(terraform -chdir="${WORK_DIR}" output -json services_east 2>/dev/null || echo "{}")
  EAST_KEYS=$(echo "${EAST_JSON}" | jq -r 'keys | sort | join(",")' 2>/dev/null || echo "")
  if [ "${EAST_KEYS}" = "web,worker" ]; then
    pass "services_east có đúng 2 service: web + worker"
  else
    fail "services_east keys = '${EAST_KEYS}' (mong đợi 'web,worker')"
  fi

  WEST_JSON=$(terraform -chdir="${WORK_DIR}" output -json services_west 2>/dev/null || echo "{}")
  WEST_KEYS=$(echo "${WEST_JSON}" | jq -r 'keys | sort | join(",")' 2>/dev/null || echo "")
  if [ "${WEST_KEYS}" = "api" ]; then
    pass "services_west có đúng 1 service: api"
  else
    fail "services_west keys = '${WEST_KEYS}' (mong đợi 'api')"
  fi

  # web has 2 URLs; api & worker have 1.
  WEB_LEN=$(echo "${EAST_JSON}" | jq '.web | length' 2>/dev/null || echo "0")
  if [ "${WEB_LEN}" = "2" ]; then
    pass "services_east.web có 2 URL (đúng replicas=2)"
  else
    fail "services_east.web có ${WEB_LEN} URL (mong đợi 2)"
  fi

  # ---- docker cross-check ----
  if command -v docker >/dev/null 2>&1; then
    # Containers running.
    for name in tflab-06-web-0 tflab-06-web-1 tflab-06-api-0 tflab-06-worker-0; do
      if docker inspect -f '{{.State.Running}}' "${name}" 2>/dev/null | grep -q true; then
        pass "container ${name} đang chạy"
      else
        fail "container ${name} không chạy"
      fi
    done

    # Network has 4 containers attached.
    NET_NAME=$(terraform -chdir="${WORK_DIR}" output -raw network_name 2>/dev/null || echo "")
    if [ -n "${NET_NAME}" ]; then
      ATTACHED=$(docker network inspect "${NET_NAME}" -f '{{len .Containers}}' 2>/dev/null || echo "0")
      if [ "${ATTACHED}" = "4" ]; then
        pass "network ${NET_NAME} có đúng 4 container attached"
      else
        fail "network ${NET_NAME} có ${ATTACHED} container attached (mong đợi 4)"
      fi
    fi
  fi

  # ---- idempotency ----
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
