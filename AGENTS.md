# dsh-skills 仓库约定

本仓库收录 DeepSeek Harness (DSH) 专属的 agent skills。每个技能自成一个目录、一个入口 `SKILL.md`。

## 硬规则

- **绝对禁止直接改动 deepseek-harness 源代码**；能力变更以 skill / plugin / bundle / preset / profile patch 形态交付。
- `SKILL.md` 只放入口、触发条件与硬规则；细节放 `references/`，确定性步骤放 `scripts/` 并配 `tests/`。
- 技能目录名必须等于 `SKILL.md` frontmatter 里的 `name`。
- **技能目录内不得出现符号链接。** 宿主侧安装器（如 Codex 的 `skill-installer`）遇到 symlink 会直接拒绝安装。
- **技能目录内不得放 `AGENTS.md` / `CLAUDE.md` 这类 agent 指令文件。** 安装器是整目录拷贝，这类文件会落到用户机器上并被宿主当作项目级指令读取。仓库自身的约定写在本文件里。
- 新增技能后要作为独立条目加进 `.claude-plugin/marketplace.json`：一个条目一个技能，条目名等于技能目录名。

## 校验

改动后跑：

```bash
./scripts/validate.sh
./scripts/validate-marketplace.sh
node --test skills/dsh-toolcall-guard/tests/parse-toolcall.test.mjs
```
