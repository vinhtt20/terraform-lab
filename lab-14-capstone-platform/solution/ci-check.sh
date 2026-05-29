#!/usr/bin/env bash
set -euo pipefail

WORK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLAN_FILE="${WORK_DIR}/.tfplan-policy"
PLAN_JSON="${WORK_DIR}/.tfplan.json"

cleanup() {
  rm -f "${PLAN_FILE}" "${PLAN_JSON}"
}
trap cleanup EXIT

echo "▶ Step 1/3 — terraform plan -out"
terraform -chdir="${WORK_DIR}" plan -out="${PLAN_FILE}" -no-color -input=false >/dev/null

echo "▶ Step 2/3 — conftest policy gate"
if command -v conftest >/dev/null 2>&1; then
  terraform -chdir="${WORK_DIR}" show -json "${PLAN_FILE}" > "${PLAN_JSON}"
  conftest test "${PLAN_JSON}" --policy "${WORK_DIR}/policies"
else
  echo "  ⚠️  conftest not installed; skipping policy gate."
fi

echo "▶ Step 3/3 — terraform test"
terraform -chdir="${WORK_DIR}" test -no-color

echo "✅ Capstone CI gate passed."
