# 解析规则：`<tool_call>` 伪 XML 文本块

某些模型把工具调用输出为纯文本伪 XML，例如：

```xml
<tool_call>
<function=auto_dev_delivery_route>
<parameter=architecture_boundary>
False
</parameter>
</function>
</tool_call>
```

DSH 只执行原生 function call，此类文本块永不执行。本页定义解析规则（继承自已退役插件 `dsh-toolcall-guard` 的 `src/xml-parser.js`，已单测）。

## 结构

- 块以 `<tool_call>` 开始，以 `</tool_call>` 结束；
- 块内含恰好一个 `<function=NAME>`；
- 0 或多个 `<parameter=KEY>\nVALUE\n</parameter>` 参数对；
- 块内其他标签忽略。

## 提取规则

1. **取最后一块**：文本中取**最后一个** `<tool_call>` 到其后的 `</tool_call>`（模型会重复输出，最新意图为准）。`</tool_call>` 缺失时取到文本末尾。
2. **函数名**：`/<function=([A-Za-z0-9_.\-]+)>/`。无匹配 → 解析失败（返回 null）。
3. **参数**：`/<parameter=([A-Za-z0-9_.\-]+)>([\s\S]*?)<\/parameter>/g` 全量匹配；值为**修剪空白后**的原样文本（多行、中文、特殊字符保留）。
4. **失败即静默**：解析不出合法函数名 → 不猜测、不执行、不注入，向用户展示原文。

## 确定性工具

需要机器可复现的解析时运行（等价于上述规则）：

```bash
node scripts/parse-toolcall.mjs < block.txt
# 输出 {"name":"auto_dev_delivery_route","parameters":{"architecture_boundary":"False"},...} 或 null
```

## 样例

| 输入 | 结果 |
|---|---|
| 无 `<tool_call>` 的普通文本 | null |
| 块内无 `<function=...>` | null（含 `<function=123>` 等非法名） |
| `<function=foo>` + 两个 `<parameter=...>` 对 | `{name:'foo', parameters:{k1:v1, k2:v2}}` |
| 两个连续 `<tool_call>` 块 | 取第二个 |

## 边界

- 参数值是**字符串**：数字/布尔在 XML 文本中按原样字符串处理，重发为原生调用时交给工具 schema 校验；
- 块缺闭合标签：仍可提取函数名，参数可能不完整——以提取到为准；
- 嵌套/畸形标签：正则容错有限，失败返回 null，不猜测。
