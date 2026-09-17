<div align="center">

# dsh-skills

**DeepSeek Harness 专属技能，一个技能一个目录** · 写插件、排查运行时、处理工具调用故障

[![skills](https://img.shields.io/badge/skills-1-blue)](#技能)
[![license](https://img.shields.io/badge/license-MIT-green)](LICENSE)
[![validate](https://github.com/plyflai/dsh-skills/actions/workflows/validate.yml/badge.svg)](https://github.com/plyflai/dsh-skills/actions/workflows/validate.yml)

</div>

---

## dsh-toolcall-guard

> **模型把工具调用写成了文本块，会话卡死时救回来。** 它输出 `<tool_call>` 伪 XML 而工具从未执行——本技能引导模型用原生 function call 重发恰好一次，然后回到原任务。

[**→ 完整说明（触发条件 / 边界 / 测试）**](skills/dsh-toolcall-guard/)

这些情况会命中它：

- 模型最近的输出里有 `<tool_call>` / `<function=...>` 文本块，而对应工具从未执行
- 模型连续重复同一个失败调用 ≥ 2 次
- 用户直接指出「工具没执行 / 会话卡住 / 别再用 XML 块」

**按需加载，零常驻 token 成本**——它不挂在任何 hook 上，未命中触发条件时不进入上下文。

```bash
git clone https://github.com/plyflai/dsh-skills && cd dsh-skills
./scripts/install.sh dsh-toolcall-guard --target ~/.dsh/skills
```

`~/.dsh/skills` 是 DSH skill-filesystem 的用户根目录，watch 默认开启：软链接就位后下一个模型 step 就进入技能目录，**无需重启**。

## 技能

每个技能自成一个目录、一个入口 `SKILL.md`，**互不隶属**。目录名 = `SKILL.md` 里的 `name`。

| 技能 | 一句话 | 依赖 |
| --- | --- | --- |
| [`dsh-toolcall-guard`](skills/dsh-toolcall-guard/) | 模型把工具调用输出成 `<tool_call>` 伪 XML 文本块导致会话卡死时，按需加载并引导模型原生重发、停止重复、继续原任务 | Node ≥ 18（仅可选的确定性解析脚本） |
| [`_template`](skills/_template/) | 新增技能的骨架，复制改名即用（以下划线开头，不参与安装） | 无 |

通用技能（与 harness 解耦）不在本仓库，见 [plyflai/agent-skills](https://github.com/plyflai/agent-skills)。

**判断标准**：如果这个技能里的知识换了 harness 就作废，它属于这里；否则归 agent-skills。

## 安装

不管哪个 harness，本质都是**把技能目录放到它读技能的地方**。

```bash
./scripts/install.sh dsh-toolcall-guard --target <你的技能目录>          # 复制
./scripts/install.sh dsh-toolcall-guard --target <你的技能目录> --link   # 软链接，git pull 后立即生效
./scripts/install.sh --list                                             # 看有哪些技能
./scripts/install.sh --all --target <你的技能目录>                      # 全部装
```

也可以手动把 `skills/<技能名>/` 整个目录拷进技能目录。

### 各 harness 装在哪

| Harness | 用户级 | 项目级 | 调用 |
| --- | --- | --- | --- |
| **跨工具通用** | `~/.agents/skills/` | `.agents/skills/` | 取决于各 harness |
| **Codex CLI** | `~/.agents/skills/`<br>`~/.codex/skills/` | `.agents/skills/`（从 cwd 逐级扫到仓库根） | `/skills` 或 `$<技能名>` |
| **Gemini CLI** | `~/.agents/skills/`<br>`~/.gemini/skills/` | `.agents/skills/`<br>`.gemini/skills/` | 说完需求后模型自行激活，需你确认 |
| **Qwen Code** | `~/.qwen/skills/` | `.qwen/skills/` | `/<技能名>` 或 `/skills` 面板 |
| **Claude Code** | `~/.claude/skills/` | `.claude/skills/` | 说完需求后模型自行调用，或 `/<技能名>` |
| **DSH** | `~/.agents/skills/`<br>`~/.dsh/skills/` | `.agents/skills/`<br>`.dsh/skills/` | 说完需求后模型自行加载 |

### 装一次，多个 harness 共用

`~/.agents/skills/` 是**跨工具共用路径**，Codex、Gemini CLI、DSH 都会读它（Gemini CLI 官方原话是「`.agents/skills/` 别名提供了一条可互操作的路径，跨不同 AI 工具保持兼容」，DSH 把它作为 `user-agents` 源读取）。所以最省事的装法是：

```bash
git clone https://github.com/plyflai/agent-skills && cd agent-skills
./scripts/install.sh deeptalk --target ~/.agents/skills
```

Claude Code 和 Qwen Code 不认这个路径，各装一份即可（用 `--link` 免得复制多份）：

```bash
./scripts/install.sh deeptalk --target ~/.claude/skills --link   # Claude Code
./scripts/install.sh deeptalk --target ~/.qwen/skills   --link   # Qwen Code
```

### 用各 harness 自带的安装器

```bash
# Codex
codex plugin marketplace add plyflai/agent-skills
codex plugin add deeptalk@plyflai-skills

# Gemini CLI
gemini skills install https://github.com/plyflai/agent-skills.git --path skills/deeptalk

# Claude Code
/plugin marketplace add plyflai/agent-skills
/plugin install deeptalk@plyflai-skills
```

> `.claude-plugin/marketplace.json` 不只 Claude Code 读——**Codex 也读**（实测 `codex plugin marketplace add` 能解析出 `deeptalk@plyflai-skills` 并安装成功）。所以这一个文件同时服务两个 harness。

### 其他 harness

Gemini CLI、Codex、DSH、Claude Code、Qwen Code 的路径都来自官方文档或源码。你自己用的 harness 若不在上表（Cursor、Windsurf、Cline、Roo Code、GitHub Copilot 等），**请查它的官方文档确认技能目录，不要照搬别家的路径**。

共同点只有一条：把含 `SKILL.md` 的整个目录放进它扫描技能的位置。技能目录名要和 `SKILL.md` 里的 `name` 一致。

### 调用方式

Agent Skills 是**按需加载**的：harness 启动时只注入每个技能的 `name` 和 `description`，命中触发条件时才读整个 `SKILL.md`。所以 `description` 里写的是「什么时候用我」，不是「我有什么功能」。


## 技能怎么用

技能是**按需加载**的：agent 只在请求命中 `SKILL.md` frontmatter 里的 `description` 时才读它。所以 `description` 写的是触发条件，不是功能介绍。

以 `dsh-toolcall-guard` 为例，它做四件事：定位并解析历史里的 XML 块 → 用**原生 function call** 重发恰好一次 → 停止重复 → 回到原任务。

它**没有** host 侧代执行能力，一切调用由模型自己发起，权限与 guard 照常生效——技能是行为指引，不是强制钩子。

## 新增一个技能

```bash
cp -R skills/_template skills/my-new-skill
# 改 skills/my-new-skill/SKILL.md 的 name（必须与目录名一致）与 description
./scripts/validate.sh
```

新增后把它作为**独立条目**加进 `.claude-plugin/marketplace.json`——一个条目一个技能，条目名等于技能目录名。`./scripts/validate-marketplace.sh` 会检查这两点，合并成伞形条目会被直接报错。

## 仓库结构

```text
dsh-skills/
├── skills/
│   ├── _template/              # 新增技能骨架（不参与安装）
│   └── dsh-toolcall-guard/     # 一个技能一个目录，目录名 = SKILL.md 里的 name
│       ├── SKILL.md            # 入口，必须
│       ├── README.md           # 这个技能自己的说明页
│       ├── references/         # 细节文档，按需读取
│       ├── scripts/            # 可执行脚本，可被 CI 测试
│       └── tests/
├── scripts/
│   ├── install.sh
│   ├── validate.sh
│   └── validate-marketplace.sh
├── .claude-plugin/
│   └── marketplace.json        # 每个技能一个独立条目
├── .github/workflows/validate.yml
├── LICENSE
└── README.md
```

## 校验

```bash
./scripts/validate.sh              # 结构与 frontmatter（CI 跑同一个）
./scripts/validate-marketplace.sh  # 清单与 skills/ 是否一致（CI 跑同一个）
node --test skills/dsh-toolcall-guard/tests/parse-toolcall.test.mjs
```

`validate.sh` 检查：`SKILL.md` 存在且 frontmatter 合法、`name` 与目录名一致且符合命名规范、`description` 非空且不超 1024 字符、`SKILL.md` 内引用的相对路径真实存在、目录内无 `.DS_Store` 与嵌套 git 仓库。

`validate-marketplace.sh` 检查：清单 JSON 合法、marketplace 名不是 Claude Code 保留名、**一个条目只声明一个技能**、条目名等于技能目录名、`skills/` 下的真技能没有漏声明。

## License

[MIT](LICENSE) © 2026 plyflai
