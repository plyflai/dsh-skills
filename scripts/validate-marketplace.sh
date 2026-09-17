#!/usr/bin/env bash
# marketplace.json 校验：检查仓库根的 Claude Code 插件清单是否合法。
# 只依赖 bash / python3。
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MANIFEST="${MARKETPLACE_OVERRIDE:-$REPO_ROOT/.claude-plugin/marketplace.json}"

ERRORS=0
err() { printf '  \033[31m✗\033[0m %s\n' "$1"; ERRORS=$((ERRORS + 1)); }
ok()  { printf '  \033[32m✓\033[0m %s\n' "$1"; }

printf '\n\033[1m校验 marketplace.json\033[0m  (%s)\n\n' "$MANIFEST"

if [ ! -f "$MANIFEST" ]; then
  echo "找不到清单文件：$MANIFEST" >&2
  exit 1
fi

# 保留名清单：来自 Claude Code 官方文档 plugin-marketplaces 的 Reserved names 节。
# 命中会让整个 marketplace 拒绝加载（官方会持续复核，不只是添加时校验一次）。
RESERVED='claude-code-marketplace claude-code-plugins claude-plugins-official
claude-plugins-community claude-community anthropic-marketplace anthropic-plugins
agent-skills anthropic-agent-skills knowledge-work-plugins life-sciences
claude-for-legal claude-for-financial-services financial-services-plugins
first-party-plugins claude-tag-plugins healthcare'

python3 - "$MANIFEST" "$REPO_ROOT" $RESERVED <<'PY'
import json, pathlib, re, sys

manifest = pathlib.Path(sys.argv[1])
repo_root = pathlib.Path(sys.argv[2])
reserved = set(sys.argv[3:])

out, errors = [], 0
def ok(m):
    print(f'  \033[32m✓\033[0m {m}')
def err(m):
    global errors
    errors += 1
    print(f'  \033[31m✗\033[0m {m}')

try:
    data = json.loads(manifest.read_text('utf-8'))
except Exception as e:
    err(f'JSON 解析失败：{e}')
    sys.exit(1)
ok('JSON 合法')

# --- 顶层必填字段 ---
for field in ('name', 'owner', 'plugins'):
    if field not in data:
        err(f'缺少顶层必填字段 {field}')

name = data.get('name', '')
if not isinstance(name, str) or not name:
    err('顶层 name 必须是非空字符串')
elif name in reserved:
    err(f'顶层 name "{name}" 是 Claude Code 保留名，marketplace 会拒绝加载，请换一个')
elif not re.fullmatch(r'[a-z0-9]+(-[a-z0-9]+)*', name):
    err(f'顶层 name "{name}" 不符合 kebab-case')
else:
    ok(f'name = {name}（非保留名，kebab-case）')

owner = data.get('owner')
if not isinstance(owner, dict) or not owner.get('name'):
    err('owner.name 必填')
else:
    ok(f'owner.name = {owner["name"]}')

plugins = data.get('plugins')
if not isinstance(plugins, list) or not plugins:
    err('plugins 必须是非空数组')
    sys.exit(1)

seen_plugin_names = set()
declared_paths = []
for i, entry in enumerate(plugins):
    label = f'plugins[{i}]'
    if not isinstance(entry, dict):
        err(f'{label} 必须是对象')
        continue
    pname = entry.get('name')
    if not pname:
        err(f'{label} 缺少 name')
    elif pname in seen_plugin_names:
        err(f'{label} name "{pname}" 与前面的条目重复')
    else:
        seen_plugin_names.add(pname)

    if 'source' not in entry:
        err(f'{label} 缺少 source')

    # 本仓库是 skills-only：必须是仓库根 source + strict:false，否则会去找不存在的 plugin.json
    if entry.get('source') != './':
        err(f'{label} source 应为 "./"（skills-only 仓库）')
    if entry.get('strict') is not False:
        err(f'{label} strict 应为 false（skills-only 仓库没有 plugin.json）')

    skills = entry.get('skills')
    if not isinstance(skills, list) or not skills:
        err(f'{label} 缺少 skills 数组')
        continue
    # 每个技能必须是它自己的一等条目：一个 plugin 一个 skill。
    # 否则技能会被塞进一个伞形条目里，用户装到的是「某个大类」而不是这个技能，
    # 技能名与安装名对不上，技能本身也失去了自己的身份。
    if len(skills) > 1:
        err(f'{label} 声明了 {len(skills)} 个技能；每个技能应各自成为一个 plugin 条目，不要用伞形条目合并')
    for s in skills:
        if not isinstance(s, str) or not s.startswith('./'):
            err(f'{label} skills 项 "{s}" 必须是以 ./ 开头的相对路径')
            continue
        declared_paths.append((label, s))
        # 条目名应与技能目录名一致：用户看到和安装的就是技能名本身
        skill_dir_name = pathlib.PurePosixPath(s).name
        if pname and pname != skill_dir_name:
            err(f'{label} name "{pname}" 与技能目录名 "{skill_dir_name}" 不一致，应改成目录名')

    ok(f'{label} name = {pname or "?"}，声明 {len(skills)} 个技能')

# --- 声明的技能路径必须真实存在 ---
if not declared_paths:
    err('没有任何声明出来的技能路径，整个 marketplace 会安装出空插件')
else:
    for label, s in declared_paths:
        target = repo_root / s
        if not target.is_dir():
            err(f'{label} 声明的 {s} 不是已存在的目录')
        elif not (target / 'SKILL.md').is_file():
            err(f'{label} 声明的 {s} 缺少 SKILL.md')
        else:
            ok(f'{s} → 存在且含 SKILL.md')

# --- 反向检查：真实技能都必须被声明，否则装了 marketplace 也拿不到 ---
if (repo_root / 'skills').is_dir():
    real = sorted(
        d.name for d in (repo_root / 'skills').iterdir()
        if d.is_dir() and not d.name.startswith('_')
    )
    declared_names = {pathlib.PurePosixPath(s).name for _, s in declared_paths}
    missing = [n for n in real if n not in declared_names]
    if missing:
        err('以下技能目录存在但没写进清单，用户装了 marketplace 也拿不到：' + ', '.join(missing))
    else:
        ok(f'skills/ 下 {len(real)} 个技能全部已被清单声明')

sys.exit(1 if errors else 0)
PY
status=$?

if [ "$status" -ne 0 ]; then
  printf '\033[31m失败：marketplace.json 校验未通过\033[0m\n\n'
  exit 1
fi

printf '\033[32m通过：marketplace.json 合规\033[0m\n\n'
