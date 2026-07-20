# 飞行器三自由度仿真程序 - 实现计划

> **创建日期**: 2026-07-20
> **对应设计**: `docs/superpowers/specs/2026-07-20-aircraft-3dof-simulation-design.md`
> **状态**: 待审核

---

## 概述

基于已批准的设计文档,将实现工作分解为 8 个有序任务,每个任务遵循 TDD(RED→GREEN→REFACTOR)原则,可独立验证。

**目标目录**: `trajectory_3dof/`(新建,与现有 `trajectory_planning/` 并列)

---

## 任务清单

### 任务 1: 项目骨架与配置模块

**目标**: 创建目录结构,实现 `config.m`

**文件**:
- `trajectory_3dof/config.m`

**步骤**:
1. 创建 `trajectory_3dof/` 目录
2. 编写 `config.m`,返回 `cfg` 结构体,包含:
   - 飞行器参数:m, S, CD0, K, CLalpha, P0, t_burn, m_fuel, Isp
   - 大气参数:g0, R, gamma_air, M_air, T0, p0, rho0
   - 积分选项:rtol, atol, t_end, dt_out
   - 初始状态:x0 = [x0, y0, h0, V0, gamma0, psi0]
3. 参数校验:assert 质量/面积为正
4. 测试:`test_config.m` 验证结构体字段完整、量纲正确

**验证**: `runtests('tests/test_config.m')` 通过

---

### 任务 2: 标准大气模块

**目标**: 实现 ISA 标准大气模型 `atmosphere.m`

**文件**:
- `trajectory_3dof/atmosphere.m`
- `trajectory_3dof/tests/test_atmosphere.m`

**步骤**:
1. 编写 `atmosphere.m`,函数签名 `[rho, a, T, p] = atmosphere(h)`
2. 实现 ISA 分层模型(对流层 0-11km,平流层 11-20km,等)
3. 边界处理:h<0 返回海平面值;h>86km 截断+警告
4. 测试:
   - 海平面对照(T0=288.15K, p0=101325Pa, rho0=1.225kg/m³)
   - 11km 处对照标准值
   - 负高度返回海平面值

**验证**: `runtests('tests/test_atmosphere.m')` 通过

---

### 任务 3: 气动模块

**目标**: 实现 `aerodynamics.m`,计算阻力/升力

**文件**:
- `trajectory_3dof/aerodynamics.m`
- `trajectory_3dof/tests/test_aerodynamics.m`

**步骤**:
1. 编写 `aerodynamics.m`,签名 `[D, L, Ma, q] = aerodynamics(x, cfg, alpha)`
2. 动压计算:q = 0.5 * rho * V²
3. 马赫数:Ma = V / a
4. 阻力系数:CD = CD0 + K * CL²
5. 升力系数:CL = CLalpha * alpha
6. 气动力:D = q * S * CD, L = q * S * CL
7. Ma>5 时外推警告
8. 测试:
   - 海平面+亚音速对照手算值
   - 零攻角时 L=0
   - 高马赫数触发警告

**验证**: `runtests('tests/test_aerodynamics.m')` 通过

---

### 任务 4: 动力学模块

**目标**: 实现核心状态导数 `dynamics.m`

**文件**:
- `trajectory_3dof/dynamics.m`
- `trajectory_3dof/tests/test_dynamics.m`

**步骤**:
1. 编写 `dynamics.m`,签名 `xdot = dynamics(t, x, cfg)`
2. 解包状态:x, y, h, V, gamma, psi
3. 调用 atmosphere(h) 获取 rho, a
4. 调用 aerodynamics(x, cfg, alpha) 获取 D, L
5. 推力逻辑:t<=t_burn 时 P=P0 且 m 递减,否则 P=0
6. 状态方程(见设计文档 §4.1)
7. V<1 时 gamma 方程用 epsilon=1 保护
8. NaN 检测:若状态发散返回 Inf
9. 测试:
   - 真空抛体(P=0, D=0)对照解析解
   - 静止状态(V=0)不奇异
   - 量纲检查

**验证**: `runtests('tests/test_dynamics.m')` 通过

---

### 任务 5: 积分器与事件检测

**目标**: 实现仿真主循环,使用 ode45 + 事件函数

**文件**:
- `trajectory_3dof/simulate.m`
- `trajectory_3dof/tests/test_simulate.m`

**步骤**:
1. 编写 `simulate.m`,签名 `[t_hist, x_hist, info] = simulate(cfg)`
2. 定义事件函数 `ground_event(t, x)`:检测 h<=0,终止方向 -1
3. 调用 ode45:`ode45(@(t,x) dynamics(t, x, cfg), [0, t_end], x0, options)`
4. 记录时间序列 t_hist, 状态序列 x_hist
5. info 结构体:impact_time, impact_x, impact_y, max_h, max_V
6. 测试:
   - 45° 真空弹道对照解析射程 R=V0²·sin(2θ)/g
   - 能量守恒(无阻力+无推力)
   - 事件函数正确触发

**验证**: `runtests('tests/test_simulate.m')` 通过

---

### 任务 6: 可视化模块

**目标**: 实现 `visualize.m`,三维轨迹 + 曲线

**文件**:
- `trajectory_3dof/visualize.m`
- `trajectory_3dof/tests/test_visualize.m`

**步骤**:
1. 编写 `visualize.m`,签名 `visualize(t_hist, x_hist, cfg)`
2. 图1:三维轨迹 comet3 动画(plot3 静态 + comet3 动态)
3. 图2:subplot 四宫格
   - 高度 vs 时间
   - 速度 vs 时间
   - 航迹角 vs 时间
   - 马赫数 vs 时间
4. 标注:坐标轴、图例、单位、标题
5. 测试:
   - 调用不报错
   - 图窗数量正确
   - 轨迹连续无跳变(对照数据)

**验证**: `runtests('tests/test_visualize.m')` 通过

---

### 任务 7: 后处理模块

**目标**: 实现 `postprocess.m`,指标统计与数据导出

**文件**:
- `trajectory_3dof/postprocess.m`
- `trajectory_3dof/tests/test_postprocess.m`

**步骤**:
1. 编写 `postprocess.m`,签名 `[metrics] = postprocess(t_hist, x_hist, cfg)`
2. 计算指标:
   - 射程 R = sqrt(x_end² + y_end²)
   - 最大高度 max_h
   - 飞行时间 t_flight
   - 最大速度 max_V
   - 最大马赫数 max_Ma
3. 导出:保存为 .mat 文件和 .csv 文件
4. 打印摘要到命令行
5. 测试:
   - 已知输入对照手算指标
   - 文件正确写入
   - 量纲检查

**验证**: `runtests('tests/test_postprocess.m')` 通过

---

### 任务 8: 主脚本集成与端到端测试

**目标**: 实现 `main.m`,集成所有模块,运行完整算例

**文件**:
- `trajectory_3dof/main.m`
- `trajectory_3dof/tests/test_e2e.m`

**步骤**:
1. 编写 `main.m`,编排流程:
   - `cfg = config()`
   - `[t_hist, x_hist, info] = simulate(cfg)`
   - `visualize(t_hist, x_hist, cfg)`
   - `metrics = postprocess(t_hist, x_hist, cfg)`
2. 端到端测试:
   - 运行 `main.m` 不报错
   - 生成图窗
   - 输出 metrics 结构体字段完整
   - 基准算例(45° 真空弹道)射程误差 < 1%
   - 主动段算例速度增量符合齐奥尔科夫斯基近似
3. 打印最终摘要

**验证**: `runtests('tests/test_e2e.m')` 通过;`main.m` 可独立运行

---

## 执行方式

**推荐**: 子代理驱动(subagent-driven-development)
- 每个任务派遣独立子代理实现
- 子代理内部遵循 TDD
- 任务完成后代码审查(requesting-code-review)

**备选**: 手动逐任务实现

---

## 依赖关系

```
任务1(骨架+config) ─┬─→ 任务2(atmosphere) ─┐
                     ├─→ 任务3(aerodynamics)─┤
                     │                       ├─→ 任务4(dynamics) ─→ 任务5(simulate) ─┬→ 任务8(集成)
                     │                       │                                      ├─→ 任务6(visualize) ─┤
                     │                       │                                      └─→ 任务7(postprocess)─┘
                     └──────────────────────────────────────────────────────────────────────────→ 任务8
```

- 任务1是所有后续任务的基础
- 任务2、3 可并行,但都依赖任务1
- 任务4 依赖任务2、3
- 任务5 依赖任务4
- 任务6、7 依赖任务5
- 任务8 依赖所有任务

---

## 验收标准

1. 所有 8 个任务的测试通过
2. `main.m` 可独立运行,生成三维轨迹图和曲线图
3. 基准算例(45° 真空弹道)射程误差 < 1%
4. 主动段算例速度增量符合齐奥尔科夫斯基近似
5. 代码量适中,模块边界清晰,适合教学

---

**文档结束**
