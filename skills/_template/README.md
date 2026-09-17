# _template

这是新增技能的骨架，不是可用技能。用法：

```bash
cp -R skills/_template skills/my-new-skill
# 改 SKILL.md 的 name（必须等于目录名）与 description
../../scripts/validate.sh
```

目录名以下划线开头，因此**不参与安装**（`install.sh` 会跳过），但会被校验，可以当格式参考。

## 为什么这样拆

| 内容 | 放哪 | 原因 |
| --- | --- | --- |
| 触发条件、硬规则、读取顺序 | `SKILL.md` | 加载技能时就要读到 |
| 长表格、领域知识、边界枚举 | `references/` | 只有真正需要时才读，省上下文 |
| 需要确定性结果的步骤 | `scripts/` + `tests/` | 可被 CI 重复验证 |
| 需要人拍板的取舍 | 不写文件，问用户 | 技能不该替用户决定 |

## 检查清单

- [ ] `name` 改成目录名，只含小写字母、数字、连字符
- [ ] `description` 写的是「什么时候用」，不是「它是什么」
- [ ] 触发条件是可观察的，不是「当用户需要帮助时」
- [ ] 写了「不应触发」的情况，避免技能越界干预
- [ ] `SKILL.md` 里的相对引用都能被 `scripts/validate.sh` 找到
- [ ] 更新根 `README.md` 的技能清单表格
