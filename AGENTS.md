# 项目规则

## 自动化开发工作流（最高优先级）

本项目包含一个**自动化开发工作流系统**，用于将用户的研究方向需求自动转化为论文和代码。

### 启动规则

**当用户在对话中输入"继续"（或"continue"、"启动工作流"等类似指令）时，你必须：**

1. **读取工作流文件**：读取 `workflow-automation/auto-dev-workflow.md` 的完整内容
2. **执行工作流**：严格按照该文件中描述的工作流执行，你就是其中定义的 Orchestrator（编排器）
3. **工作流步骤 0**：首先执行 `GET http://localhost:8765/api/request` 获取用户在前端提交的需求
4. **自动流转**：之后按工作流文档自动流转，通过 WebSocket + 长轮询与前端交互，无需额外的终端输入

### 启动前提

- 前端服务器（`workflow-automation/server.py`）必须正在运行（HTTP 端口 8765，WebSocket 端口 8766）
- 若服务器未运行，提示用户运行 `workflow-automation/start.bat`
- 用户需先在浏览器前端（http://localhost:8765）提交需求，再在 TRAE 对话中输入"继续"

### 工作流概览

工作流采用 **skill 驱动 + 审阅全覆盖 + 交互精简** 模式，共 6 次用户交互：

| 批次 | 内容 | skill |
|------|------|-------|
| ① | 文献+idea选择 | research-lit + idea-creator |
| ② | 研究方案+实验计划 | novelty-check + research-review + research-refine + experiment-plan |
| ③ | 工程方案确认 | brainstorming + writing-plans + 审阅 |
| ④ | 代码实现确认 | subagent-driven-development + verification |
| ⑤ | 实验+评审确认 | experiment-bridge + experiment-audit + auto-review-loop |
| ⑥ | 论文+审计确认 | paper-writing + citation-audit + kill-argument |

### 关键约束

- **所有问题必须由 `mcp_llm-chat` 从 skill 产出的文档中生成**，禁止 Orchestrator 自行编排问题
- **四层审阅全覆盖**：研究级、代码级、实验级、论文级
- **仅一次手动触发**：用户只需输入"继续"，之后所有步骤通过 WebSocket 自动流转
- **双技能包协同**：ARIS（研究+审阅+论文）+ SP（工程+代码）

### 详细工作流

完整工作流定义见：`workflow-automation/auto-dev-workflow.md`

### 通信协议

- 提交问题：`POST http://localhost:8765/api/questions`
- 等待回答：`GET http://localhost:8765/api/wait_answers?timeout=300`
- 更新状态：`POST http://localhost:8765/api/status`
- 记录日志：`POST http://localhost:8765/api/log`

### 技能包位置

- ARIS 技能包：`.trae/skills/`（80 个研究技能）
- SP 技能包：`skills/`（14 个工程技能）
- 审阅 MCP：`mcp_llm-chat`（chat 工具）
