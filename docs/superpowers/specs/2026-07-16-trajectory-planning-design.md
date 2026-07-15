# 固定翼飞行器 3D 动态目标拦截轨迹规划算法设计

**日期**: 2026-07-16  
**状态**: 设计完成，待用户审查  
**实现语言**: MATLAB

---

## 1. 概述

### 1.1 问题定义

设计一个固定翼飞行器在三维空间中拦截匀速直线运动目标的轨迹规划算法。系统采用**混合架构**：离线层通过最优控制问题（OCP）生成基准拦截轨迹，在线层通过模型预测控制（MPC）实时修正偏差。

### 1.2 需求汇总

| 维度 | 选择 |
|------|------|
| 飞行器类型 | 固定翼飞行器 |
| 关键约束 | 最小转弯半径、速度下限、不可悬停 |
| 规划场景 | 动态目标追踪/拦截 |
| 目标运动模式 | 匀速直线运动 |
| 规划空间维度 | 3D 空间 |
| 实时性要求 | 混合（预规划 + 在线修正） |
| 实现语言 | MATLAB |

### 1.3 方案选择

在 3 种候选方案中选择**方案 B：最优控制轨迹优化 + MPC 在线修正**：

- 离线层：Direct Collocation 将 OCP 离散化为 NLP，`fmincon` 求解
- 在线层：线性化 MPC 滚动求解 QP，`quadprog` 求解

---

## 2. 系统架构

### 2.1 双层架构

```
系统输入 (x0, u0, target_state, target_vel, params)
        │
        ▼
┌───────────────────────┐
│  离线层：OCP 轨迹规划   │
│  · Direct Collocation  │
│  · 目标函数: min Tf     │
│  · fmincon (SQP)       │
│  · 输出: x_ref(t),     │
│    u_ref(t), Tf        │
└───────────┬───────────┘
            │
            ▼
┌───────────────────────┐
│  在线层：MPC 修正      │
│  · 滚动时域优化        │
│  · 预测时域 Np = 10    │
│  · 每步求解 QP         │
│  · quadprog            │
│  · 输出: u_corr(t)     │
└───────────┬───────────┘
            │
            ▼
┌───────────────────────┐
│  飞行器动力学模型       │
│  (3D, 非线性, 6 状态)  │
└───────────────────────┘
```

### 2.2 数据流

1. 离线 OCP 接收初始状态和目标信息，生成基准轨迹 `traj_ref`, `ctrl_ref` 和终端时间 `Tf`
2. MPC 以 `Δt_mpc = 0.1s` 周期运行，从基准轨迹提取当前时刻参考，结合实际状态求解修正控制量
3. 仿真器用 RK4 积分飞行器动力学，记录状态序列
4. 当 `t_now > 0.8 * Tf` 时触发重规划，以当前实际状态为起点重新调用 OCP

### 2.3 MATLAB 工具链依赖

- `fmincon`（Optimization Toolbox）— OCP 求解
- `quadprog`（Optimization Toolbox）— MPC 的 QP 求解
- 标准绘图函数 — 可视化

---

## 3. 飞行器动力学模型

### 3.1 状态量与控制量

**状态向量** $\mathbf{x} = [x, y, z, V, \chi, \gamma]^T \in \mathbb{R}^6$

| 分量 | 含义 | 单位 |
|------|------|------|
| $x, y, z$ | 3D 位置 | m |
| $V$ | 飞行速度 | m/s |
| $\chi$ | 航向角（水平面内，从 x 轴起逆时针） | rad |
| $\gamma$ | 航迹角（垂直面内，水平面为 0） | rad |

**控制向量** $\mathbf{u} = [\dot{\chi}, \dot{\gamma}, \dot{V}]^T \in \mathbb{R}^3$

| 分量 | 含义 | 单位 |
|------|------|------|
| $\dot{\chi}$ | 航向角速率 | rad/s |
| $\dot{\gamma}$ | 航迹角速率 | rad/s |
| $\dot{V}$ | 加速度 | m/s² |

### 3.2 动力学方程

$$\dot{x} = V \cos\gamma \cos\chi$$

$$\dot{y} = V \cos\gamma \sin\chi$$

$$\dot{z} = V \sin\gamma$$

$$\dot{V} = u_V$$

$$\dot{\chi} = u_\chi$$

$$\dot{\gamma} = u_\gamma$$

### 3.3 物理约束

| 约束 | 表达式 | 默认值 |
|------|--------|--------|
| 速度范围 | $V_{\min} \leq V \leq V_{\max}$ | 30 ~ 80 m/s |
| 航向角速率 | $\|\dot{\chi}\| \leq \dot{\chi}_{\max}$ | 0.15 rad/s |
| 航迹角范围 | $\|\gamma\| \leq \gamma_{\max}$ | 0.35 rad (~20°) |
| 航迹角速率 | $\|\dot{\gamma}\| \leq \dot{\gamma}_{\max}$ | 0.10 rad/s |
| 加速度 | $\|\dot{V}\| \leq \dot{V}_{\max}$ | 5 m/s² |
| 高度 | $z \geq z_{\min}$ | 场景相关 |

最小转弯半径由 $R_{\min} = V / \dot{\chi}_{\max}$ 决定。

### 3.4 目标模型

匀速直线运动目标，状态 $\mathbf{x}_t = [x_t, y_t, z_t]^T$，恒定速度 $\mathbf{v}_t = [v_{tx}, v_{ty}, v_{tz}]^T$：

$$\mathbf{x}_t(t) = \mathbf{x}_t(t_0) + \mathbf{v}_t \cdot (t - t_0)$$

### 3.5 拦截条件

$$\|\mathbf{p}(t_f) - \mathbf{p}_t(t_f)\| \leq d_{\text{capture}}$$

捕获半径 $d_{\text{capture}} = 100$ m。

---

## 4. 离线 OCP 轨迹规划

### 4.1 OCP 数学表述

**目标函数** — 最小化拦截时间 + 控制平滑性惩罚：

$$J = T_f + w \int_0^{T_f} \|\mathbf{u}(t) - \mathbf{u}_{\text{prev}}(t)\|^2 dt$$

**边界条件**：

| 条件 | 表达式 |
|------|--------|
| 初始状态 | $\mathbf{x}(0) = \mathbf{x}_0$ |
| 初始控制 | $\mathbf{u}(0) = \mathbf{u}_0$ |
| 终端拦截 | $\|\mathbf{p}(T_f) - \mathbf{p}_t(T_f)\| \leq d_{\text{capture}}$ |

**路径约束**：第 3.3 节定义的全部物理约束。

### 4.2 离散化：Hermite-Simpson 直接配点

时间区间 $[0, T_f]$ 等分为 $N = 40$ 段。每段内用三次 Hermite 多项式逼近状态轨迹，中点用 Simpson 积分保证动力学一致性。

对第 $i$ 个配点区间 $[t_i, t_{i+1}]$（$h = T_f / N$）：

$$\mathbf{x}_{i+1} = \mathbf{x}_i + \frac{h}{6}\left[\mathbf{f}_i + 4\mathbf{f}_m + \mathbf{f}_{i+1}\right]$$

中点状态由 Hermite 插值：

$$\mathbf{x}_m = \frac{\mathbf{x}_i + \mathbf{x}_{i+1}}{2} + \frac{h}{8}(\mathbf{f}_i - \mathbf{f}_{i+1})$$

### 4.3 NLP 变量结构

决策变量：

$$\mathbf{Z} = [\mathbf{x}_0, \mathbf{u}_0, \mathbf{x}_1, \mathbf{u}_1, \ldots, \mathbf{x}_N, \mathbf{u}_N, T_f]^T \in \mathbb{R}^{7N+7}$$

共 $7 \times 41 + 1 = 288$ 个决策变量。

### 4.4 求解配置

```matlab
options = optimoptions('fmincon', ...
    'Algorithm', 'sqp', ...
    'MaxFunctionEvaluations', 1e4, ...
    'StepTolerance', 1e-8, ...
    'ConstraintTolerance', 1e-6, ...
    'Display', 'iter');
```

### 4.5 接口

```matlab
function [traj_ref, ctrl_ref, Tf, info] = plan_offline_OCP(...
    x0, u0, target_state, target_vel, params)
% 输入: 初始状态[6x1], 初始控制[3x1], 目标位置[3x1], 目标速度[3x1], 参数
% 输出: traj_ref[6x(N+1)], ctrl_ref[3x(N+1)], Tf, info(exitflag,cost,iter)
```

---

## 5. 在线 MPC 修正

### 5.1 工作流程

每个控制周期 $\Delta t_{\text{mpc}} = 0.1$s：

1. 获取飞行器当前实际状态 $\mathbf{x}_{\text{actual}}$
2. 从基准轨迹提取当前时刻参考 $\mathbf{x}_{\text{ref}}(t_{\text{now}})$, $\mathbf{u}_{\text{ref}}(t_{\text{now}})$
3. 获取目标最新位置 $\mathbf{p}_{\text{target}}$
4. 在线性化预测模型上求解 QP，得到最优控制增量序列
5. 仅执行第一个控制量 $\mathbf{u}_{\text{corr}} = \mathbf{u}_{\text{ref}} + \delta\mathbf{u}_0$

### 5.2 线性化预测模型

在基准轨迹工作点处一阶泰勒展开：

$$\delta\dot{\mathbf{x}} = A_k \delta\mathbf{x} + B_k \delta\mathbf{u}$$

$$A_k = \left.\frac{\partial \mathbf{f}}{\partial \mathbf{x}}\right|_{\mathbf{x}_{\text{ref}}, \mathbf{u}_{\text{ref}}}, \quad B_k = \left.\frac{\partial \mathbf{f}}{\partial \mathbf{u}}\right|_{\mathbf{x}_{\text{ref}}, \mathbf{u}_{\text{ref}}}$$

前向欧拉离散化（$\Delta t = \Delta t_{\text{mpc}} = 0.1$s，即 MPC 控制周期）：

$$\delta\mathbf{x}_{k+1} = \Phi_k \delta\mathbf{x}_k + \Gamma_k \delta\mathbf{u}_k$$

$$\Phi_k = I + A_k \Delta t, \quad \Gamma_k = B_k \Delta t$$

### 5.3 QP 问题

**预测时域** $N_p = 10$，**控制时域** $N_c = 5$。

**目标函数**：

$$\min_{\delta\mathbf{U}} \sum_{k=0}^{N_p-1} \left( \|\delta\mathbf{x}_k\|_Q^2 + \|\delta\mathbf{u}_k\|_R^2 \right) + \|\delta\mathbf{x}_{N_p}\|_P^2$$

**约束**：

| 约束类型 | 表达式 |
|----------|--------|
| 控制增量 | $\|\delta\mathbf{u}_{k+1} - \delta\mathbf{u}_k\| \leq \Delta \mathbf{u}_{\max}$ |
| 控制量范围 | $\mathbf{u}_{\text{ref}} + \delta\mathbf{u}_k \in [\mathbf{u}_{\min}, \mathbf{u}_{\max}]$ |
| 状态范围 | $\mathbf{x}_{\text{ref}} + \delta\mathbf{x}_k \in [\mathbf{x}_{\min}, \mathbf{x}_{\max}]$ |

### 5.4 权重矩阵

| 权重 | 结构 | 设计原则 | 默认值 |
|------|------|----------|--------|
| $Q$ | $\text{diag}(q_p, q_p, q_p, q_v, q_\chi, q_\gamma)$ | 位置权重 $q_p$ 大，角度权重适中 | $q_p=10, q_v=1, q_\chi=1, q_\gamma=1$ |
| $R$ | $\text{diag}(r_\chi, r_\gamma, r_V) \cdot r_0$ | $r_0$ 较小，允许积极修正 | $r_\chi=r_\gamma=r_V=1, r_0=0.1$ |
| $P$ | 终端权重 | 取离散代数 Riccati 方程的解 | 离线计算 |

### 5.5 重规划机制

- 触发条件：$t_{\text{now}} > 0.8 T_f$ 且未拦截
- 以当前实际状态为初始条件，重新调用 `plan_offline_OCP`
- 防抖：两次重规划间隔不小于 $2 N_p \Delta t$

### 5.6 接口

```matlab
function [u_corr, replan_flag] = mpc_correct(...
    x_actual, t_now, traj_ref, ctrl_ref, Tf, target_pos, params)
% 输入: 实际状态[6x1], 当前时间, 基准轨迹, 基准控制, 终端时间, 目标位置[3x1], 参数
% 输出: 修正控制[3x1], 重规划标志
```

---

## 6. 模块划分与文件结构

```
trajectory_planning/
├── main.m                      % 主入口
├── config/
│   └── params.m                % 全局参数结构体
├── dynamics/
│   ├── dynamics_model.m        % 飞行器非线性动力学 f(x,u)
│   ├── jacobian_dynamics.m     % 解析雅可比 A=∂f/∂x, B=∂f/∂u
│   └── target_model.m          % 匀速直线目标运动模型
├── ocp/
│   ├── plan_offline_OCP.m      % 离线 OCP 主函数
│   ├── ocp_cost.m              % 目标函数 J
│   ├── ocp_constraints.m       % 非线性约束
│   └── ocp_collocation.m       % Hermite-Simpson 配点离散化
├── mpc/
│   ├── mpc_correct.m           % 在线 MPC 修正主函数
│   ├── mpc_build_qp.m          % QP 矩阵构建
│   ├── mpc_linearize.m         % 工作点线性化 + 离散化
│   └── mpc_replan_trigger.m    % 重规划触发判断
├── simulation/
│   ├── simulate.m              % 闭环仿真循环
│   └── integrator.m            % RK4 积分器
├── visualization/
│   ├── plot_trajectory.m       % 3D 轨迹绘制
│   ├── plot_comparison.m       % 基准 vs 实际轨迹对比
│   └── plot_error.m            % 跟踪误差曲线
└── tests/
    ├── test_dynamics.m          % 动力学正确性
    ├── test_ocp_convergence.m   % OCP 收敛性
    ├── test_mpc_stability.m     % MPC 闭环稳定性
    └── test_intercept.m         % 端到端拦截测试
```

### 模块依赖关系

| 模块 | 职责 | 依赖 |
|------|------|------|
| `config` | 集中管理参数 | 无 |
| `dynamics` | 动力学方程和雅可比 | 无 |
| `ocp` | 离线基准轨迹生成 | `dynamics`, `config` |
| `mpc` | 在线实时修正 | `dynamics`, `config` |
| `simulation` | 闭环仿真验证 | `dynamics`, `ocp`, `mpc` |
| `visualization` | 结果可视化 | 无 |
| `tests` | 单元测试与集成测试 | 所有模块 |

---

## 7. 仿真验证与测试

### 7.1 仿真流程

```
初始化 → 离线 OCP → 仿真循环:
  MPC 求解 → RK4 积分 → 目标运动 → 记录 → 重规划判断 → 拦截判断
→ 输出结果与可视化
```

### 7.2 测试矩阵

| 测试 | 类型 | 验证目标 | 通过条件 |
|------|------|----------|----------|
| `test_dynamics` | 单元 | 动力学方程数值正确 | 与解析解误差 < 1e-10 |
| `test_ocp_convergence` | 单元 | OCP 求解器收敛 | exitflag > 0，约束违反 < 1e-6 |
| `test_ocp_constraints` | 单元 | 路径约束全程满足 | $V, \dot\chi, \gamma, \dot V$ 全程在范围内 |
| `test_mpc_stability` | 单元 | MPC 闭环不发散 | 10s 仿真内状态有界，误差收敛 |
| `test_intercept_nominal` | 集成 | 标称场景拦截成功 | 拦截距离 ≤ $d_{\text{capture}}$ |
| `test_intercept_wind` | 集成 | 风扰动下仍拦截 | 5m/s 恒定风扰动，拦截成功 |
| `test_replan` | 集成 | 重规划机制正常 | 目标速度方向突变 30°，重规划后拦截成功 |

### 7.3 默认参数表

| 参数 | 符号 | 默认值 | 单位 |
|------|------|--------|------|
| 最小速度 | $V_{\min}$ | 30 | m/s |
| 最大速度 | $V_{\max}$ | 80 | m/s |
| 最大航向角速率 | $\dot\chi_{\max}$ | 0.15 | rad/s |
| 最大航迹角 | $\gamma_{\max}$ | 0.35 | rad |
| 最大航迹角速率 | $\dot\gamma_{\max}$ | 0.10 | rad/s |
| 最大加速度 | $\dot V_{\max}$ | 5 | m/s² |
| 捕获半径 | $d_{\text{capture}}$ | 100 | m |
| OCP 配点数 | $N$ | 40 | - |
| MPC 预测时域 | $N_p$ | 10 | - |
| MPC 控制时域 | $N_c$ | 5 | - |
| MPC 周期 | $\Delta t_{\text{mpc}}$ | 0.1 | s |
| OCP 平滑权重 | $w$ | 0.01 | - |

---

## 8. YAGNI 排除项

以下功能明确不在本次设计范围内：

- 障碍物避让（当前场景无障碍物需求）
- 多目标拦截（用户选择单目标）
- 多机协同（用户选择单机）
- 目标机动预测（目标是匀速直线，可解析预测）
- Simulink 集成（纯 MATLAB 脚本实现即可验证）
- 实时硬件部署（研究验证阶段）

---

*文档结束*
