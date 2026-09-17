---
name: dsh-toolcall-guard
description: '引导模型从"工具调用格式错误"状态恢复：当你的工具调用被输出成 `<tool_call>`/`<function=...>`/`<parameter=...>` 伪 XML 文本块（永远不会被执行）、你发现自己连续重复同一失败调用、或用户指出会话卡住/工具未执行时，加载本技能：定位并解析历史中的 XML 块，用原生 function call 重发一次，停止重复，继续原任务。Use when your tool calls are emitted as pseudo-XML text blocks that never execute, or you are stuck repeating the same failed call: parse the block and re-issue it as a native function call.'
---

# dsh-toolcall-guard

> 本环境只执行原生 function call；`<tool_call>` XML 文本块永远不会被执行。本技能引导模型自行恢复：解析块 → 原生重发 → 停止重复 → 继续任务。它是给模型的行为指引，不是脚本清单。

## 激活标识

进入 skill 时输出：`🧰 dsh-toolcall-guard 已激活`

## 触发（何时加载）

满足任一即加载：

- 你的上一条或近几条 assistant 输出里含有 `<tool_call>` 文本块（含 `<function=...>` / `<parameter=...>`），而对应工具从未执行；
- 你发现自己连续重复同一工具调用（同一名字、同一参数）≥ 2 次仍未成功；
- 用户指出"工具没执行 / 会话卡住 / 别再用 XML 块"。

不应触发（加载后无动作，直接继续）：

- 工具调用全部是正常原生 function call——无 XML 块时不干预；
- 与工具调用格式无关的卡死（权限拒绝、参数非法、网络错误等）——这是通用调试，不是本技能职责；
- 用户要求解析与工具调用无关的任意 XML 文本。

## 默认目标

1. **自检**：查看最近 1-3 条 assistant 输出，定位最后一个未执行的 `<tool_call>` 块。
2. **解析**：按 [parsing-rules.md](references/parsing-rules.md) 提取 function 名与参数；需要确定性结果时运行 `scripts/parse-toolcall.mjs`。
3. **重发**：工具在当下工具列表中 → 立即用**原生 function call** 重发（同名字、同参数、恰好一次）。
4. **拒绝**：工具不在列表或名字非法 → 不伪造调用，向用户展示解析结果并请求指示。
5. **继续**：重发成功后回到原任务；不再输出任何 XML 块，不叙事、不道歉、不复述格式规则。
6. **停止**：同一块在历史中已有执行结果 → 直接继续，不再重复调用。

## 读取顺序

1. [parsing-rules.md](references/parsing-rules.md) — 块结构与解析规则（含边界）
2. [recovery-protocol.md](references/recovery-protocol.md) — 完整恢复流程、稳定文案与失败处理
3. 需要确定性解析时：`node scripts/parse-toolcall.mjs`（stdin 输入，JSON 输出）

## 硬规则

- ⛔ 绝不再次输出 `<tool_call>` / `<function=...>` / `<parameter=...>` 文本块。
- ⛔ 不伪造执行结果：工具必须真实调用，成功/失败以调用返回为准。
- ⛔ 同一调用不重复轰炸：重发恰好一次；再失败立即停止并报告，等待用户指示。
- ✅ 解析失败（无合法 `<function=...>`）：不猜测工具名，展示原文请求确认。
- ✅ 执行结果已在历史中：静默继续原任务，不重复触发。
