#!/usr/bin/env bash
# grade.sh — chạy verify.sh trên tất cả lab và tổng hợp kết quả
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT}"

GREEN='\033[0;32m'; RED='\033[0;31m'; CYAN='\033[0;36m'; NC='\033[0m'

# Cho phép chấm 1 lab cụ thể: bash scripts/grade.sh lab-07-terraform-import
TARGETS=("$@")
if [[ ${#TARGETS[@]} -eq 0 ]]; then
  mapfile -t TARGETS < <(ls -d lab-* 2>/dev/null | sort)
fi

if [[ ${#TARGETS[@]} -eq 0 ]]; then
  echo "Không tìm thấy thư mục lab-*"
  exit 1
fi

PASS=0; FAIL=0; SKIP=0
declare -a RESULTS

for lab in "${TARGETS[@]}"; do
  if [[ ! -d "${lab}" ]]; then
    echo -e "${RED}!! Không tìm thấy ${lab}${NC}"
    SKIP=$((SKIP+1)); RESULTS+=("SKIP ${lab}")
    continue
  fi
  if [[ ! -x "${lab}/verify.sh" ]] && [[ ! -f "${lab}/verify.sh" ]]; then
    echo -e "${CYAN}-- ${lab}: chưa có verify.sh, bỏ qua${NC}"
    SKIP=$((SKIP+1)); RESULTS+=("SKIP ${lab}")
    continue
  fi

  echo -e "${CYAN}==> ${lab}${NC}"
  if bash "${lab}/verify.sh"; then
    PASS=$((PASS+1)); RESULTS+=("PASS ${lab}")
  else
    FAIL=$((FAIL+1)); RESULTS+=("FAIL ${lab}")
  fi
  echo
done

echo "──────────────── Tổng hợp ────────────────"
for r in "${RESULTS[@]}"; do
  case "${r}" in
    PASS*) echo -e "${GREEN}${r}${NC}" ;;
    FAIL*) echo -e "${RED}${r}${NC}" ;;
    *)     echo "${r}" ;;
  esac
done
echo "──────────────────────────────────────────"
echo "PASS=${PASS}  FAIL=${FAIL}  SKIP=${SKIP}"

[[ ${FAIL} -eq 0 ]] && exit 0 || exit 1
