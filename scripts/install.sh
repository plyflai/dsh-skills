#!/usr/bin/env bash
# 把本仓库的技能安装到任意技能目录（复制或软链接）。
#
#   ./scripts/install.sh deeptalk --target ~/.claude/skills
#   ./scripts/install.sh deeptalk --target ~/.dsh/skills --link
#   ./scripts/install.sh --all --target ~/.codex/skills
#   ./scripts/install.sh --list
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILLS_DIR="$REPO_ROOT/skills"

TARGET=""
LINK=0
FORCE=0
SELECTED=()
ALL=0

usage() {
  cat <<'EOF'
用法: install.sh [技能名...] [选项]

选项:
  -t, --target <目录>   安装目标目录（必填，除非用 --list）
  -l, --link            建软链接而不是复制（git pull 后立即生效）
  -f, --force           目标已存在时先删除再安装
      --all             安装 skills/ 下的全部技能
      --list            只列出可用技能
  -h, --help            显示本帮助

示例:
  ./scripts/install.sh deeptalk --target ~/.claude/skills
  ./scripts/install.sh --all -t ~/.dsh/skills --link
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    -t|--target) TARGET="${2:-}"; shift 2 ;;
    -l|--link)   LINK=1; shift ;;
    -f|--force)  FORCE=1; shift ;;
    --all)       ALL=1; shift ;;
    --list)      printf '可用技能：\n'; for d in "$SKILLS_DIR"/*/; do [ -d "$d" ] || continue; printf '  %s\n' "$(basename "$d")"; done; exit 0 ;;
    -h|--help)   usage; exit 0 ;;
    -*)          echo "未知选项：$1" >&2; usage >&2; exit 2 ;;
    *)           SELECTED+=("$1"); shift ;;
  esac
done

if [ "$ALL" -eq 1 ]; then
  SELECTED=()
  for d in "$SKILLS_DIR"/*/; do
    [ -d "$d" ] || continue
    SELECTED+=("$(basename "$d")")
  done
fi

if [ "${#SELECTED[@]}" -eq 0 ]; then
  echo "没有指定技能。用 --list 看可用技能，或 --all 安装全部。" >&2
  exit 2
fi

if [ -z "$TARGET" ]; then
  echo "必须用 --target 指定安装目录（例如 --target ~/.claude/skills）。" >&2
  exit 2
fi

# 展开 ~ 与相对路径
case "$TARGET" in
  "~"/*) TARGET="$HOME/${TARGET#\~/}" ;;
  "~")   TARGET="$HOME" ;;
esac
mkdir -p "$TARGET"
TARGET="$(cd "$TARGET" && pwd)"

echo
FAILED=0
for name in "${SELECTED[@]}"; do
  src="$SKILLS_DIR/$name"
  dst="$TARGET/$name"

  if [ ! -d "$src" ]; then
    printf '  \033[31m✗\033[0m %s：skills/%s 不存在\n' "$name" "$name"
    FAILED=$((FAILED + 1))
    continue
  fi
  if [ ! -f "$src/SKILL.md" ]; then
    printf '  \033[31m✗\033[0m %s：缺少 SKILL.md，不是合法技能，已跳过\n' "$name"
    FAILED=$((FAILED + 1))
    continue
  fi

  if [ -e "$dst" ] || [ -L "$dst" ]; then
    if [ "$FORCE" -eq 1 ]; then
      rm -rf "$dst"
    else
      printf '  \033[33m!\033[0m %s：%s 已存在，跳过（要覆盖加 --force）\n' "$name" "$dst"
      continue
    fi
  fi

  if [ "$LINK" -eq 1 ]; then
    ln -s "$src" "$dst"
    printf '  \033[32m✓\033[0m %s → %s（软链接）\n' "$name" "$dst"
  else
    cp -R "$src" "$dst"
    rm -f "$dst/.DS_Store"
    printf '  \033[32m✓\033[0m %s → %s（复制）\n' "$name" "$dst"
  fi
done
echo
exit $(( FAILED > 0 ? 1 : 0 ))
