# dsh-toolcall-guard

本目录是 DSH 技能源码。约定：

- 绝对禁止直接改动 deepseek-harness 源代码；能力变更以 skill / plugin / bundle / preset / profile patch 形态交付。
- `SKILL.md` 只放入口、触发条件与硬规则；细节放 `references/`，确定性步骤放 `scripts/` 并配 `tests/`。
- 改动后跑 `../../scripts/validate.sh` 与 `node --test tests/parse-toolcall.test.mjs`。
