#!/usr/bin/env bash
# check-env.sh — verify required tools for tflab
set -uo pipefail

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[0;33m'; NC='\033[0m'
ok()   { echo -e "${GREEN}✅${NC} $1"; }
bad()  { echo -e "${RED}❌${NC} $1"; FAIL=$((FAIL+1)); }
warn() { echo -e "${YELLOW}⚠ ${NC} $1"; }

FAIL=0

# semver-ish compare: returns 0 if $1 >= $2
ver_ge() {
  printf '%s\n%s\n' "$2" "$1" | sort -V -C
}

# terraform
if command -v terraform >/dev/null; then
  TF_VER=$(terraform version -json 2>/dev/null | jq -r '.terraform_version' 2>/dev/null \
           || terraform version | head -1 | awk '{print $2}' | tr -d v)
  if ver_ge "${TF_VER}" "1.9.0"; then
    ok "terraform >= 1.9.0  (v${TF_VER})"
  else
    bad "terraform < 1.9.0  (v${TF_VER}) — cần nâng cấp"
  fi
else
  bad "terraform: không tìm thấy lệnh"
fi

# docker
if command -v docker >/dev/null; then
  DK_VER=$(docker version --format '{{.Client.Version}}' 2>/dev/null || echo "")
  if [[ -n "${DK_VER}" ]] && docker ps >/dev/null 2>&1; then
    ok "docker chạy được     (${DK_VER})"
  else
    bad "docker cài rồi nhưng daemon không chạy hoặc thiếu quyền"
  fi
else
  bad "docker: không tìm thấy lệnh"
fi

# jq
if command -v jq >/dev/null; then
  ok "jq present           ($(jq --version))"
else
  bad "jq: không tìm thấy — brew install jq"
fi

# bash >= 4
BASH_MAJOR=${BASH_VERSION%%.*}
if [[ "${BASH_MAJOR}" -ge 4 ]]; then
  ok "bash >= 4.0          (${BASH_VERSION})"
else
  warn "bash < 4.0 (${BASH_VERSION}) — một vài verify.sh dùng tính năng bash 4+; brew install bash"
fi

# git
if command -v git >/dev/null; then
  ok "git present          ($(git --version | awk '{print $3}'))"
else
  bad "git: không tìm thấy"
fi

# optional: conftest (lab 13)
if command -v conftest >/dev/null; then
  ok "conftest present     ($(conftest --version | head -1))"
else
  warn "conftest missing — chỉ cần cho lab 13: brew install conftest"
fi

# optional: tofu
if command -v tofu >/dev/null; then
  ok "opentofu present     ($(tofu version | head -1 | awk '{print $2}'))"
fi

echo
if [[ ${FAIL} -eq 0 ]]; then
  echo -e "${GREEN}Môi trường OK — sẵn sàng bắt đầu lab.${NC}"
  exit 0
else
  echo -e "${RED}Thiếu ${FAIL} công cụ bắt buộc — xem PREREQUISITES.md.${NC}"
  exit 1
fi
