#!/usr/bin/env bash
# 技能结构校验：检查 skills/ 下每个技能是否符合 SKILL.md 约定。
# 只依赖 bash / grep / sed / awk / python3（macOS 与 Linux 自带的版本即可）。
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILLS_DIR="${SKILLS_DIR_OVERRIDE:-$REPO_ROOT/skills}"

ERRORS=0
CHECKED=0
TEMPLATES=0

err() { printf '  \033[31m✗\033[0m %s\n' "$1"; ERRORS=$((ERRORS + 1)); }
ok()  { printf '  \033[32m✓\033[0m %s\n' "$1"; }

[ -d "$SKILLS_DIR" ] || { echo "找不到 skills/ 目录：$SKILLS_DIR" >&2; exit 1; }

# 取 SKILL.md frontmatter 中某个顶层标量字段的值（支持单双引号）
fm_value() {
  local file="$1" key="$2"
  awk -v key="$key" '
    NR == 1 && $0 ~ /^---[[:space:]]*$/ { in_fm = 1; next }
    in_fm && $0 ~ /^---[[:space:]]*$/     { exit }
    in_fm {
      if ($0 ~ "^" key "[[:space:]]*:") {
        sub("^" key "[[:space:]]*:[[:space:]]*", "")
        gsub(/^["'"'"']|["'"'"']$/, "")
        print
        exit
      }
    }
  ' "$file"
}

printf '\n\033[1m校验 dsh skills\033[0m  (%s)\n\n' "$SKILLS_DIR"

for dir in "$SKILLS_DIR"/*/; do
  [ -d "$dir" ] || continue
  name="$(basename "$dir")"
  case "$name" in _*) TEMPLATES=$((TEMPLATES + 1)) ;; esac
  CHECKED=$((CHECKED + 1))
  printf '\033[1m%s\033[0m\n' "$name"

  skill_md="$dir/SKILL.md"
  if [ ! -f "$skill_md" ]; then
    err "缺少 SKILL.md"
    continue
  fi

  # --- 1. frontmatter 存在且首行为 ---
  if [ "$(head -n 1 "$skill_md" | tr -d '[:space:]')" != "---" ]; then
    err "SKILL.md 首行必须是 --- 开头（frontmatter 缺失）"
    continue
  fi
  if ! awk 'NR > 1 && $0 ~ /^---[[:space:]]*$/ { found = 1; exit } END { exit !found }' "$skill_md"; then
    err "frontmatter 没有闭合的 ---"
    continue
  fi
  ok "frontmatter 已闭合"

  # --- 2. name 字段 ---
  fm_name="$(fm_value "$skill_md" name)"
  if [ -z "$fm_name" ]; then
    err "frontmatter 缺少 name"
  elif [ "$fm_name" != "$name" ]; then
    err "name \"$fm_name\" 与目录名 \"$name\" 不一致"
  elif ! printf '%s' "$fm_name" | grep -Eq '^_?[a-z0-9]+(-[a-z0-9]+)*$'; then
    err "name \"$fm_name\" 不符合规范（只允许小写字母、数字、连字符；骨架可用 _ 前缀）"
  elif [ "${#fm_name}" -gt 64 ]; then
    err "name \"$fm_name\" 超过 64 字符"
  else
    ok "name = ${fm_name}（与目录名一致）"
  fi

  # --- 3. description 字段 ---
  fm_desc="$(fm_value "$skill_md" description)"
  if [ -z "$fm_desc" ]; then
    err "frontmatter 缺少 description（agent 靠它决定何时加载本技能）"
  elif [ "${#fm_desc}" -lt 20 ]; then
    err "description 过短（${#fm_desc} 字符），应说明「什么时候用」"
  elif [ "${#fm_desc}" -gt 1024 ]; then
    err "description 超过 1024 字符（规范上限）"
  else
    ok "description 存在（${#fm_desc} 字符）"
  fi

  # --- 4. 文档里引用的相对路径必须真实存在 ---
  # 允许两种基准：技能目录内，或仓库根（用来引用 scripts/、LICENSE 这类仓库级文件）。
  # mode=strict：SKILL.md，markdown 链接与行内代码里的文件名都算引用。
  # mode=loose ：技能自己的 README.md，只查 markdown 链接——README 大量用 <你的技能目录> 这类占位符。
  missing_refs() {
    python3 - "$1" "$dir" "$REPO_ROOT" "$2" <<'PY'
import re, sys, pathlib
md = pathlib.Path(sys.argv[1])
roots = [pathlib.Path(sys.argv[2]), pathlib.Path(sys.argv[3])]
mode = sys.argv[4]
text = md.read_text('utf-8', errors='replace')
refs = set()
for m in re.finditer(r'\]\(([^)#\s]+)\)', text):          # markdown 链接
    refs.add(m.group(1))
if mode == 'strict':
    for m in re.finditer(r'`([\w./-]+\.(?:md|py|sh|ya?ml|json|mjs|js))`', text):
        refs.add(m.group(1))
for r in sorted(refs):
    if r.startswith(('http://', 'https://', 'mailto:', '/')):
        continue
    if '<' in r or '>' in r:        # 文档占位符，不是真路径
        continue
    if not any((root / r).exists() for root in roots):
        print(r)
PY
  }

  missing="$(missing_refs "$skill_md" strict)"
  if [ -n "$missing" ]; then
    while IFS= read -r ref; do
      [ -n "$ref" ] && err "SKILL.md 引用了不存在的文件：$ref"
    done <<< "$missing"
  else
    ok "SKILL.md 里的相对引用全部存在"
  fi

  # --- 4b. 技能自己的 README.md（它会被安装器一起拷给用户）---
  if [ -f "$dir/README.md" ]; then
    missing="$(missing_refs "$dir/README.md" loose)"
    if [ -n "$missing" ]; then
      while IFS= read -r ref; do
        [ -n "$ref" ] && err "README.md 引用了不存在的文件：$ref"
      done <<< "$missing"
    else
      ok "README.md 里的相对链接全部存在"
    fi
  fi

  # --- 5. 无 .DS_Store ---
  if find "$dir" -name '.DS_Store' -print -quit | grep -q .; then
    err "技能目录内有 .DS_Store（本地垃圾文件，不应提交）"
  else
    ok "无 .DS_Store"
  fi

  # --- 6. 无嵌套 git 仓库 ---
  if [ -e "$dir/.git" ]; then
    err "技能目录内嵌套了 git 仓库（应为普通目录）"
  else
    ok "无嵌套 git 仓库"
  fi

  # --- 7. 无符号链接 ---
  # 宿主侧安装器整目录拷贝技能；Codex 的 skill-installer 遇到 symlink 直接拒绝安装。
  if [ -n "$(find "$dir" -type l -print -quit)" ]; then
    err "技能目录内有符号链接（安装会被拒绝）：$(find "$dir" -type l | head -3 | tr '\n' ' ')"
  else
    ok "无符号链接"
  fi

  # --- 8. 无 agent 指令文件 ---
  # 整目录拷贝会把这类文件装到用户机器上，被宿主当作项目级指令读取。
  stray="$(find "$dir" -maxdepth 2 -type f \( -name 'AGENTS.md' -o -name 'CLAUDE.md' \) -print | sed "s|^$dir/||" | tr '\n' ' ')"
  if [ -n "$stray" ]; then
    err "技能目录内有 agent 指令文件（会被装到用户机器上）：$stray"
  else
    ok "无 agent 指令文件"
  fi
  echo
done

if [ "$CHECKED" -eq 0 ]; then
  echo "skills/ 下没有找到任何技能目录" >&2
  exit 1
fi

if [ "$ERRORS" -gt 0 ]; then
  printf '\033[31m失败：%d 个技能，%d 个问题\033[0m\n\n' "$CHECKED" "$ERRORS"
  exit 1
fi

printf '\033[32m通过：%d 个技能全部合规\033[0m' "$CHECKED"
[ "$TEMPLATES" -gt 0 ] && printf '（含 %d 个骨架，不参与安装）' "$TEMPLATES"
printf '\n\n'
