#!/usr/bin/env bash
# ci-check.sh — reference solution. Same orchestration as starter/ci-check.sh.

set -euo pipefail

if ! command -v conftest >/dev/null 2>&1; then
  echo "❌ 'conftest' not found in PATH."
  echo "   Install: brew install conftest   # macOS"
  echo "   Or:      https://www.conftest.dev/install/"
  exit 127
fi

WORK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLAN_FILE="${WORK_DIR}/.tfplan-policy"
PLAN_JSON="${WORK_DIR}/.tfplan.json"

cleanup() {
  rm -f "${PLAN_FILE}" "${PLAN_JSON}"
}
trap cleanup EXIT

echo "▶ terraform plan -out=${PLAN_FILE}"
terraform -chdir="${WORK_DIR}" plan -out="${PLAN_FILE}" -no-color -input=false >/dev/null

echo "▶ terraform show -json > plan.json"
terraform -chdir="${WORK_DIR}" show -json "${PLAN_FILE}" > "${PLAN_JSON}"

echo "▶ conftest test plan.json --policy policies/"
conftest test "${PLAN_JSON}" --policy "${WORK_DIR}/policies"
