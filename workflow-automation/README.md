# 自动化开发工作流 v4

> **双技能包协同 · 双智能体执行 · 研究+实现复合型项目**

## 工作流架构

本工作流采用**三角色协同**模式，将"软件工程"与"学术研究"任务分离为两个独立智能体执行，避免冲突：

| 角色 | 身份 | 职责 |
|------|------|------|
| **Orchestrator** | TRAE 主线程 | 读取工作流文件、管理前端问答、派发 Agent、管理交接点 |
| **ARIS Agent** | Task 子智能体 | 研究方向确认、实验部署、论文写作、学术审计（ARIS 技能包） |
| **SP Agent** | Task 子智能体 | 工程需求澄清、TDD 实现、代码审查（Superpowers 技能包） |

### 冲突避免

- **时序隔离**：SP Agent 和 ARIS Agent 不会并发执行
- **目录隔离**：SP 写 `src/tests/docs/`，ARIS 写 `research_wiki/experiments/paper/`
- **修改权回传**：ARIS 发现代码 bug 时回传 SP 修复，不直接改 `src/`
- **技能不交叉**：各 Agent 只调用自己技能包的技能

## 快速开始

### 1. 启动交互服务器

双击 `start.bat`，浏览器自动打开 `http://localhost:8765`

### 2. 在前端输入研究方向

输入选题方向或具体研究内容（均可拆分为论文+实现）：

```
例如: 基于深度强化学习的飞行器姿态自适应控制
例如: 无人机集群协同航迹规划算法
例如: 飞行器三自由度仿真程序（纯实现）
```

点击"提交需求"，页面提示"请在 TRAE 中输入 继续 启动工作流"

### 3. 在 TRAE 中启动工作流

告诉 TRAE：

```
读取 workflow-automation/auto-dev-workflow.md 并执行
```

然后在 TRAE 对话框输入"继续"

### 4. 对话驱动流程

工作流采用**对话驱动 + 批量问答**模式，共 7 批交互：

```
用户: 继续           → TRAE 派发 ARIS Agent，在前端生成一批问题
用户(前端): 逐个回答   → 前端提示"收集完成，请在 TRAE 中输入确认"
用户: 确认           → TRAE 读取回答，处理，生成下一批问题
...循环直到完成
```

## 工作流阶段

| 阶段 | 主导 Agent | 问答批次 | 产出 |
|------|-----------|----------|------|
| 1. 研究方向确认 | ARIS Agent | 批次1(6题) + 批次2(5题) | research_method.md |
| 2. 工程需求与设计 | SP Agent | 批次3(5题) + 批次4(4题) | design.md, plan.md |
| 3. 代码实现 | SP Agent | 自动执行(仅阻塞时交互) | src/, tests/ |
| 4. 实验部署与执行 | ARIS Agent | 批次5(3题) | experiments/runs/ |
| 5. 论文写作与审计 | ARIS Agent | 批次6(3题) | paper.pdf |
| 6. 交付确认 | Orchestrator | 批次7(2题) | 最终交付清单 |

### 三个交接点

- **#0 研究→工程**：research_method.md → SP brainstorming 翻译为工程需求
- **#1 代码→实验**：src/ 代码 → ARIS experiment-bridge 包装为实验
- **#2 结果→论文**：metrics.json → ARIS result-to-claim 判定后写入论文

## 交互模式说明

| 阶段 | 用户操作 |
|------|----------|
| 启动 | 前端输入研究方向 → TRAE 输入"继续" |
| 每批问题 | TRAE 生成问题到前端 → 前端逐个回答 → 前端提示"收集完成" → TRAE 输入"确认" |
| 自动执行 | TRAE 自动派发 Agent 执行，无需用户干预 |
| 交付 | TRAE 提交交付确认到前端 → 前端确认 → TRAE 输入"确认" |

**最小化交互**：7 批共 28 个问题，每批多个问题一次性确认。

## 灵活路由

工作流会根据需求自动选择路径：

- **复合型（论文+实现）**：全流程 6 阶段（默认）
- **纯开发（无论文）**：跳过 ARIS 研究和论文阶段，仅 SP 开发
- **纯研究（无代码）**：跳过 SP 开发阶段，使用现有数据/代码

## 文件说明

| 文件 | 用途 |
|------|------|
| `auto-dev-workflow.md` | 工作流编排提示词 v4（双智能体协同版） |
| `server.py` | Python HTTP 服务器（批量问答 API） |
| `ui.html` | 前端交互网页（批量问题展示 + 收集完成提示） |
| `start.bat` | Windows 启动脚本 |

## API 接口

| 接口 | 方法 | 说明 |
|------|------|------|
| `/api/request` | POST | 用户提交研究方向 |
| `/api/request` | GET | TRAE 获取研究方向 |
| `/api/questions` | POST | TRAE 提交一批问题 |
| `/api/questions` | GET | 前端获取当前批次问题 |
| `/api/answer` | POST | 用户回答单个问题 |
| `/api/answers` | GET | TRAE 获取一批回答 |
| `/api/status` | GET/POST | 流程状态 |
| `/api/log` | POST | 记录日志 |
| `/api/logs` | GET | 获取日志 |
| `/api/history` | GET | 获取问答历史 |
| `/api/reset` | POST | 重置状态 |

## 相关文档

- [双技能包协同场景设计](../dual-skill-scenario-design/dual-skill-scenario-design.html) — SP × ARIS 协同方案详细设计
- [技能包对比分析](../skills-comparison-analysis/skills-comparison-analysis.html) — ARIS vs Superpowers 对比报告
