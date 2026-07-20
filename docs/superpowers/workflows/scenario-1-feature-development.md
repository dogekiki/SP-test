# 场景 1:新功能开发工作流

> **适用场景**:从零开发新功能、添加新能力、修改现有行为
> **触发词**:"构建/做一个/加一个/实现一个..."
> **前置条件**:用户提出创造性需求,且项目范围适合单一 spec 覆盖

---

## 工作流总览

```
步骤0  using-superpowers        (入口判定)
  │
  ▼
步骤1  brainstorming             (设计) ──┐
  │                                      │ 硬门控:未获批准不得继续
  ▼                                      │
步骤2  writing-plans             (计划) ◄┘
  │
  ▼
步骤3  using-git-worktrees       (隔离)
  │
  ▼
步骤4  subagent-driven-development (执行)
  │   ┌── 每任务: test-driven-development
  │   ├── 遇 bug:  systematic-debugging
  │   ├── 任务后: requesting-code-review → receiving-code-review
  │   └── 完成前: verification-before-completion
  ▼
步骤5  finishing-a-development-branch (收尾)
```

---

## 详细步骤与提示词

### 步骤 0:入口判定

**Skill**: `using-superpowers`

**执行指令**:
```
判定用户请求类型:
- 若含"构建/做一个/加一个/实现"等创造性动词 → 本工作流(场景1)
- 若含"修复/报错/失败"等 → 转场景2(调试链)
- 若含"多个...同时...不相关" → 转场景3(并行链)

过程技能优先于实现技能。判定完成后宣告:
"使用 [技能名] 来 [目的]"
```

**通过准则**:明确识别为创造性任务,进入步骤 1

---

### 步骤 1:头脑风暴与设计

**Skill**: `brainstorming`

**执行指令**:
```
按以下顺序执行 brainstorming 检查清单:

1. 探索项目上下文:
   - 检查现有文件结构、文档、近期 git 提交
   - 评估范围:若涉及多个独立子系统,转场景4(大型项目分解)

2. 适时提供可视化伴侣(仅当问题"看比说更清楚"时):
   - 作为独立消息提供,不含其他内容
   - 用户接受则用 --open 启动服务器

3. 逐个提问澄清(每条消息只问一个问题):
   - 优先多选题,开放式亦可
   - 聚焦:目的、约束、成功标准

4. 提出 2-3 种方案:
   - 含权衡分析,推荐方案打头
   - 解释推荐理由

5. 呈现设计(分段):
   - 每段按复杂度伸缩(简单几句话,微妙 200-300 字)
   - 覆盖:架构、组件、数据流、错误处理、测试
   - 每段后询问"目前看起来对吗"

6. 写设计文档:
   - 保存到 docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md
   - 提交 git

7. 规格自审(内联修复):
   - 占位符扫描、内部一致性、范围检查、歧义检查

8. 用户审核规格:
   - 等待用户响应,要求修改则重跑步骤7

9. 过渡到实现:
   - 调用 writing-plans(步骤2)
```

**硬门控**:未获用户设计批准前,不得调用任何实现技能、写代码、搭脚手架

**输出**:`docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md`

**通过准则**:用户明确批准规格

---

### 步骤 2:编写实现计划

**Skill**: `writing-plans`

**执行指令**:
```
读取步骤1产出的设计文档,按以下要求编写实现计划:

1. 假设执行者对代码库零上下文,文档化一切:
   - 动哪些文件、代码、测试、如何验证
   - DRY、YAGNI、TDD、频繁提交

2. 文件结构规划:
   - 列出将创建/修改的文件及其职责
   - 每文件单一明确职责,接口清晰

3. 任务分解(任务粒度):
   - 最小可独立测试单元
   - 每任务含自己的测试周期和审查门
   - 把 setup、配置、脚手架、文档折进相关任务

4. 每任务包含:
   - 目标说明
   - 涉及文件
   - TDD 步骤(先写测试→看失败→实现→通过)
   - 验证命令
   - 提交点

保存到 docs/superpowers/plans/YYYY-MM-DD-<feature-name>.md
```

**输出**:`docs/superpowers/plans/YYYY-MM-DD-<feature-name>.md`

**通过准则**:计划含可执行的任务列表,每任务有明确验证标准

---

### 步骤 3:工作区隔离

**Skill**: `using-git-worktrees`

**执行指令**:
```
执行工作区隔离:

步骤0: 检测现有隔离
  - 若已在 worktree 中 → 跳过创建
  - 若在 submodule 中 → 视为普通仓库

步骤1: 优先用平台原生工具
步骤2: 回退到 git worktree
步骤3: 永不与 harness 对抗

宣告:"使用 using-git-worktrees 技能设置隔离工作区"
```

**通过准则**:在隔离工作区中工作,不污染主分支

---

### 步骤 4:子代理驱动执行

**Skill**: `subagent-driven-development`

**执行指令**:
```
按计划执行,每任务派遣全新子代理:

对每个任务:
1. 派遣实现者子代理(精心构造上下文,不含会话历史)
   - 子代理内部走 test-driven-development:
     RED(写测试→看失败) → GREEN(最小实现→通过) → REFACTOR
   - 遇 bug 走 systematic-debugging(先找根因再修复)

2. 任务审查:
   - 派遣审查子代理(requesting-code-review)
   - 规格合规性 + 代码质量
   - 收到反馈走 receiving-code-review:
     READ → UNDERSTAND → VERIFY → EVALUATE → RESPOND → IMPLEMENT

3. 声称"完成"前:
   - 走 verification-before-completion
   - 必须跑验证命令拿证据,不得凭感觉声称

连续执行:任务间不暂停检查
  - 只有 BLOCKED、真正阻碍进度的歧义、或全部完成才停
  - 不问"要继续吗"
```

**内循环技能**:
- `test-driven-development`(每任务)
- `systematic-debugging`(遇 bug)
- `dispatching-parallel-agents`(任务内多独立子任务)
- `requesting-code-review` + `receiving-code-review`(任务后)
- `verification-before-completion`(声称完成前)

**通过准则**:所有计划任务完成,所有测试通过

---

### 步骤 5:完成开发分支

**Skill**: `finishing-a-development-branch`

**执行指令**:
```
所有任务完成、测试通过后:

1. 验证测试:
   - 运行项目测试套件
   - 失败则必须先修,不得继续

2. 检测环境:
   - git 仓库类型、分支状态

3. 呈现结构化选项:
   - merge 到主分支
   - 创建 PR
   - 仅清理(保留分支)

4. 执行用户选择

5. 清理工作区

宣告:"使用 finishing-a-development-branch 技能完成此工作"
```

**通过准则**:工作已集成到目标分支,工作区已清理

---

## 关键约束

| 约束 | 说明 |
|------|------|
| **硬门控** | 步骤1未获设计批准前,步骤2-5都不得开始 |
| **终态唯一** | 步骤1终态只能是步骤2;步骤4终态只能是步骤5 |
| **证据先行** | 步骤4中声称"完成"前必须跑验证命令 |
| **连续执行** | 步骤4任务间不暂停,只有 BLOCKED 或全部完成才停 |
| **过程优先** | 步骤0判定后,过程技能(brainstorming)先于实现技能 |

---

## 用户交互点

| 步骤 | 交互类型 | 等待用户输入? |
|------|----------|---------------|
| 1.3 | 逐个提问澄清 | 是(每问等一个回答) |
| 1.5 | 设计分段确认 | 是(每段等"对/不对") |
| 1.8 | 用户审核规格 | 是(等批准或修改要求) |
| 2 | 计划审核 | 可选(可设为自动继续) |
| 4 | 仅 BLOCKED 时 | 是(仅遇阻时) |
| 5 | 集成方式选择 | 是(选 merge/PR/cleanup) |

---

## 退出条件

- **正常退出**:步骤5完成,工作已集成,工作区已清理
- **异常退出**:步骤1用户放弃;步骤4 BLOCKED 无法解决
