<div align="center">

# dsh-skills

**DeepSeek Harness 专属 Agent Skills** · 面向 harness 本身的开发、排障、运维与工具调用可靠性

[![skills](https://img.shields.io/badge/skills-1-blue)](#技能清单)
[![license](https://img.shields.io/badge/license-MIT-green)](LICENSE)

</div>

---

## 这是什么

针对 **DeepSeek Harness**（DSH）这一具体 harness 的技能集合：写插件、装配 preset/bundle、排查运行时问题、处理工具调用格式故障。

与 [plyflai/agent-skills](https://github.com/plyflai/agent-skills) 的分工：

| 仓库 | 内容 | 换了 harness 还能用吗 |
| --- | --- | --- |
| **dsh-skills**（本仓库） | 讲 DSH 的 CLI、装配平面、运行时不变量、工具调用约定 | ❌ 专有知识 |
| [agent-skills](https://github.com/plyflai/agent-skills) | 与 harness 解耦的方法论型技能 | ✅ 通用 |

判断标准很简单：**如果这个技能里的知识换了 harness 就作废，它属于这里。**

## 技能清单

| 技能 | 一句话 | 依赖 |
| --- | --- | --- |
| [`dsh-toolcall-guard`](skills/dsh-toolcall-guard/) | 模型把工具调用输出成 `<tool_call>` 伪 XML 文本块导致会话卡死时，按需加载并引导模型原生重发、停止重复、继续原任务 | Node ≥ 18（仅可选的确定性解析脚本） |
| [`_template`](skills/_template/) | 新增技能的起始骨架，复制改名即用 | 无 |

## 快速开始

```bash
git clone https://github.com/plyflai/dsh-skills
cd dsh-skills
./scripts/install.sh dsh-toolcall-guard --target ~/.dsh/skills    # 复制
./scripts/install.sh dsh-toolcall-guard --target ~/.dsh/skills --link  # 软链接，git pull 后立即生效
./scripts/install.sh --list
```

`~/.dsh/skills` 是 DSH skill-filesystem 的用户根目录，watch 默认开启：软链接就位后下一个模型 step 就会进入技能目录，无需重启。

装到其他 harness 请把 `--target` 换成对应的技能目录。

### Claude Code 插件市场

仓库根带 `.claude-plugin/marketplace.json`，也可作为插件市场添加：

```bash
/plugin marketplace add plyflai/dsh-skills
/plugin install dsh-skills@plyflai-dsh-skills
```

本仓库是 skills-only，条目用 `"source": "./"` + `"strict": false` 直接指向 `skills/`，不需要每个技能各自的 `plugin.json`。清单里的 marketplace 名是 `plyflai-dsh-skills`（`agent-skills` 等名字在 Claude Code 保留名列表里，第三方用了会导致 marketplace 拒绝加载）。

## 技能怎么用

技能是**按需加载**的：agent 只在请求命中 `SKILL.md` frontmatter 里的 `description` 时才读它。所以 `description` 写的是触发条件，不是功能介绍。

以 `dsh-toolcall-guard` 为例，这些情况会命中它：

- 模型最近的输出里出现了 `<tool_call>` / `<function=...>` 文本块，而工具从未执行
- 模型连续重复同一个失败调用 ≥ 2 次
- 用户直接指出「工具没执行 / 会话卡住 / 别再用 XML 块」

它做四件事：定位并解析历史里的 XML 块 → 用**原生 function call** 重发恰好一次 → 停止重复 → 回到原任务。它**没有** host 侧代执行能力，一切调用由模型自己发起，权限与 guard 照常生效。

## 新增一个技能

```bash
cp -R skills/_template skills/my-new-skill
# 改 skills/my-new-skill/SKILL.md 的 name（必须与目录名一致）与 description
./scripts/validate.sh
```

`_template` 目录不会被当成真技能安装（名字以下划线开头），但会被校验，可以当作格式参考。

新增后记得把它加进 `.claude-plugin/marketplace.json` 的 `skills` 数组 —— `./scripts/validate-marketplace.sh` 会检查两边是否一致，漏了会报错。

## 仓库结构

```text
dsh-skills/
├── .claude-plugin/
│   └── marketplace.json        # Claude Code 插件市场清单（skills-only，指向 skills/）
├── skills/
│   ├── _template/              # 新增技能骨架（不参与安装）
│   └── dsh-toolcall-guard/
│       ├── SKILL.md            # 入口，必须
│       ├── references/         # 细节文档，按需读取
│       ├── scripts/            # 可执行脚本，可被 CI 测试
│       └── tests/
├── scripts/
│   ├── install.sh
│   ├── validate.sh
│   └── validate-marketplace.sh
├── .github/workflows/validate.yml
├── LICENSE
└── README.md
```

## 校验

```bash
./scripts/validate.sh             # 结构与 frontmatter（CI 跑同一个脚本）
./scripts/validate-marketplace.sh # 插件清单与 skills/ 是否一致（CI 跑同一个脚本）
node --test skills/dsh-toolcall-guard/tests/parse-toolcall.test.mjs
```

`validate.sh` 检查：`SKILL.md` 存在且 frontmatter 合法、`name` 与目录名一致且符合命名规范、`description` 非空且不超 1024 字符、`SKILL.md` 内引用的相对路径真实存在、目录内无 `.DS_Store` 与嵌套 git 仓库。

`validate-marketplace.sh` 检查：清单 JSON 合法、marketplace 名不是 Claude Code 保留名、每个技能条目真实存在且含 `SKILL.md`、`skills/` 下的真技能没有漏声明。

## License

[MIT](LICENSE) © 2026 plyflai
