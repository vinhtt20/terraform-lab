#!/usr/bin/env bash
# verify.sh — Lab 05 grader
# Compatible with bash 3.2 (macOS default): no associative arrays, no mapfile.

set -euo pipefail

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR="${LAB_DIR}/starter"
MODULE_DIR="${WORK_DIR}/modules/web_service"
PASS=0
FAIL=0

pass() { echo "  ✅ $1"; PASS=$((PASS+1)); }
fail() { echo "  ❌ $1"; FAIL=$((FAIL+1)); }

echo "▶ Lab 05 — verify"

# --- 1. fmt -----------------------------------------------------------------
if terraform -chdir="${WORK_DIR}" fmt -check -recursive >/dev/null 2>&1; then
  pass "terraform fmt sạch (recursive — bao gồm cả modules/)"
else
  fail "terraform fmt phát hiện file chưa format (chạy 'terraform fmt -recursive' trong starter/)"
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
for f in versions.tf variables.tf main.tf outputs.tf README.md; do
  if [ -f "${MODULE_DIR}/${f}" ]; then
    pass "module web_service có ${f}"
  else
    fail "module web_service thiếu ${f}"
  fi
done

# --- 4. anti-pattern: module must NOT have a provider {} block --------------
if grep -E '^[[:space:]]*provider[[:space:]]+"' "${MODULE_DIR}"/*.tf >/dev/null 2>&1; then
  fail "module web_service có 'provider \"...\" {}' block — anti-pattern (xem RUBRIC §Level 2)"
else
  pass "module web_service KHÔNG có 'provider {}' block (đúng best practice)"
fi

# --- 5. independent module validate (best practice for shareable modules) ---
if [ -d "${MODULE_DIR}" ]; then
  if (cd "${MODULE_DIR}" && terraform init -backend=false -input=false -no-color >/dev/null 2>&1 \
                          && terraform validate -no-color >/dev/null 2>&1); then
    pass "module web_service validate ĐỘC LẬP (init -backend=false)"
  else
    fail "module web_service không validate độc lập được"
  fi
fi

# --- 6. state assertions ----------------------------------------------------
STATE_FILE="${WORK_DIR}/terraform.tfstate"
if [ ! -f "${STATE_FILE}" ]; then
  fail "chưa có terraform.tfstate — bạn đã chạy 'terraform apply' chưa?"
else
  STATE_LIST=$(terraform -chdir="${WORK_DIR}" state list 2>/dev/null || echo "")

  # Module must be called twice (api + frontend). Expected addresses follow the
  # `module.<name>.<resource>` pattern.
  EXPECTED='module.api.docker_image.this
module.api.docker_container.this
module.frontend.docker_image.this
module.frontend.docker_container.this'

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

  # frontend has enable_log_volume = true → must have docker_volume.logs[0].
  if echo "${STATE_LIST}" | grep -qE '^module\.frontend\.docker_volume\.logs\[0\]$'; then
    pass "module.frontend tạo docker_volume.logs (enable_log_volume=true)"
  else
    fail "module.frontend thiếu docker_volume.logs[0] — đã set enable_log_volume=true chưa?"
  fi

  # api has enable_log_volume = false → must NOT have docker_volume.logs.
  if echo "${STATE_LIST}" | grep -qE '^module\.api\.docker_volume\.logs'; then
    fail "module.api KHÔNG nên có docker_volume.logs (enable_log_volume mặc định = false)"
  else
    pass "module.api KHÔNG có docker_volume.logs (đúng)"
  fi

  # frontend has index_content set → must have local_file.index[0].
  if echo "${STATE_LIST}" | grep -qE '^module\.frontend\.local_file\.index\[0\]$'; then
    pass "module.frontend tạo local_file.index (index_content != null)"
  else
    fail "module.frontend thiếu local_file.index[0]"
  fi

  # ---- outputs ----
  URLS_JSON=$(terraform -chdir="${WORK_DIR}" output -json urls 2>/dev/null || echo "{}")
  for key in api frontend; do
    URL=$(echo "${URLS_JSON}" | jq -r --arg k "${key}" '.[$k] // empty')
    if echo "${URL}" | grep -qE '^http://localhost:[0-9]+$'; then
      pass "output urls.${key} = ${URL}"
    else
      fail "output urls.${key} không hợp lệ (got: '${URL}')"
    fi
  done

  FRONT_VOL=$(terraform -chdir="${WORK_DIR}" output -raw frontend_volume 2>/dev/null || echo "")
  if echo "${FRONT_VOL}" | grep -q '^tflab-05-frontend-logs$'; then
    pass "output frontend_volume = tflab-05-frontend-logs"
  else
    fail "output frontend_volume khác mong đợi (got: '${FRONT_VOL}')"
  fi

  # ---- docker cross-check ----
  if command -v docker >/dev/null 2>&1; then
    for svc in api frontend; do
      if docker inspect -f '{{.State.Running}}' "tflab-05-${svc}" 2>/dev/null | grep -q true; then
        pass "container tflab-05-${svc} đang chạy"
      else
        fail "container tflab-05-${svc} không chạy"
      fi
    done

    # Verify volume exists for frontend only.
    if docker volume ls --format '{{.Name}}' 2>/dev/null | grep -qx 'tflab-05-frontend-logs'; then
      pass "docker volume tflab-05-frontend-logs tồn tại"
    else
      fail "docker volume tflab-05-frontend-logs không tồn tại"
    fi

    # curl frontend → custom content present.
    if command -v curl >/dev/null 2>&1; then
      FRONT_URL=$(echo "${URLS_JSON}" | jq -r '.frontend // empty')
      if [ -n "${FRONT_URL}" ]; then
        BODY=$(curl -s --max-time 5 "${FRONT_URL}" || echo "")
        if echo "${BODY}" | grep -qi 'tflab-05 Frontend'; then
          pass "curl ${FRONT_URL} trả về index_content tuỳ biến"
        else
          fail "curl ${FRONT_URL} không có nội dung tuỳ biến (mong đợi text 'tflab-05 Frontend')"
        fi
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
