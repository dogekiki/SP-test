function [traj_ref, ctrl_ref, Tf, info] = plan_offline_OCP(x0, u0, target_init, target_vel, params)
%PLAN_OFFLINE_OCP 离线 OCP 轨迹规划主求解函数
%   [traj_ref, ctrl_ref, Tf, info] = plan_offline_OCP(x0, u0, target_init, target_vel, params)
%
% 使用 fmincon 求解最优控制问题:
%   min  J = Tf + w_smooth * sum(u_k' * u_k) * h
%   s.t. Hermite-Simpson 配点缺陷 = 0
%        初始状态/控制约束, 速度/航迹角/控制上下界, 终端拦截约束
%
% 输入:
%   x0          - 初始状态 (6x1) [x;y;z;V;chi;gamma]
%   u0          - 初始控制 (3x1) [chi_dot;gamma_dot;V_dot]
%   target_init - 目标初始位置 (3x1)
%   target_vel  - 目标常速度 (3x1)
%   params      - 配置参数结构体
%
% 输出:
%   traj_ref - 参考轨迹 [6 x (N+1)], 每列为一个配点状态
%   ctrl_ref - 参考控制 [3 x (N+1)]
%   Tf       - 总飞行时间 [s]
%   info     - 求解信息: exitflag, cost, iterations

    N  = params.N;
    nZ = 9*(N+1) + 1;          % 决策变量维数
    p0 = x0(1:3);

    %% 1. 初始猜测: 前向积分的近最优碰撞航向轨迹 (V->V_max)
    %    先求 V=V_max 的碰撞航向 Tf 与瞄准点, 再用 RK4 积分得到各配点状态
    Z0 = build_rk4_guess(x0, u0, target_init, target_vel, params);
    Tf_guess = Z0(end);

    %% 2. 上下界
    lb = zeros(nZ, 1);
    ub = zeros(nZ, 1);
    for k = 0:N
        off = 9*k;
        lb(off+1) = -inf;                  ub(off+1) = inf;                 % x
        lb(off+2) = -inf;                  ub(off+2) = inf;                 % y
        lb(off+3) = params.z_min;          ub(off+3) = inf;                 % z
        lb(off+4) = params.V_min;          ub(off+4) = params.V_max;        % V
        lb(off+5) = -pi;                   ub(off+5) = pi;                  % chi
        lb(off+6) = -params.gamma_max;     ub(off+6) = params.gamma_max;    % gamma
        lb(off+7) = -params.chi_dot_max;   ub(off+7) = params.chi_dot_max;  % chi_dot
        lb(off+8) = -params.gamma_dot_max; ub(off+8) = params.gamma_dot_max;% gamma_dot
        lb(off+9) = -params.V_dot_max;     ub(off+9) = params.V_dot_max;    % V_dot
    end
    lb(end) = 1;        % Tf 下界
    ub(end) = 500;      % Tf 上界

    % TypicalX: 有限差分步长缩放, 改善变量量级差异大的数值条件
    typicalX = ones(nZ, 1);
    for k = 0:N
        off = 9*k;
        typicalX(off+1) = max(abs(p0(1)), 1);
        typicalX(off+2) = max(abs(p0(2)), 1);
        typicalX(off+3) = max(abs(p0(3)), 1);
        typicalX(off+4) = 50;
        typicalX(off+5) = 1;
        typicalX(off+6) = 0.3;
        typicalX(off+7) = params.chi_dot_max;
        typicalX(off+8) = params.gamma_dot_max;
        typicalX(off+9) = params.V_dot_max;
    end
    typicalX(end) = max(Tf_guess, 1);

    %% 3. fmincon 求解 (解析梯度, SQP, 未收敛则回退 interior-point)
    %    启用解析目标梯度与约束雅可比, 大幅加速并稳定收敛
    opts = optimoptions(params.fmincon_opts, ...
        'Display', 'off', ...
        'SpecifyObjectiveGradient', true, ...
        'SpecifyConstraintGradient', true, ...
        'CheckGradients', false, ...
        'MaxIterations', 1000, ...
        'MaxFunctionEvaluations', 5e4, ...
        'TypicalX', typicalX);

    nonlcon = @(Z) ocp_constraints(Z, x0, u0, target_init, target_vel, params);
    [Z_opt, cost, exitflag, output] = fmincon( ...
        @(Z) ocp_cost(Z, params), Z0, [], [], [], [], lb, ub, nonlcon, opts);

    if exitflag <= 0
        % 回退到 interior-point 算法 (同样使用解析梯度)
        opts_ip = optimoptions(opts, 'Algorithm', 'interior-point', ...
            'MaxIterations', 1500, 'MaxFunctionEvaluations', 1e5, ...
            'HonorBounds', true);
        [Z_opt, cost, exitflag, output] = fmincon( ...
            @(Z) ocp_cost(Z, params), Z0, [], [], [], [], lb, ub, nonlcon, opts_ip);
    end

    %% 4. 提取轨迹与控制
    traj_ref = zeros(6, N+1);
    ctrl_ref = zeros(3, N+1);
    for k = 0:N
        traj_ref(:, k+1) = Z_opt(9*k + 1 : 9*k + 6);
        ctrl_ref(:, k+1) = Z_opt(9*k + 7 : 9*k + 9);
    end
    Tf = Z_opt(end);

    info.exitflag   = exitflag;
    info.cost       = cost;
    info.iterations = output.iterations;
end

function Z0 = build_rk4_guess(x0, u0, target_init, target_vel, params)
%BUILD_RK4_GUESS 构造近最优初始猜测
%   求 V=V_max 的碰撞航向, 用最大控制率 (V_dot_max, chi_dot_max) 前向 RK4 积分,
%   在 N+1 个配点上采样, 得到接近最优且近似可行的决策变量向量。
    N   = params.N;
    nZ  = 9*(N+1) + 1;
    p0  = x0(1:3);
    Vmx = params.V_max;

    % V=V_max 碰撞航向: 固定点迭代 Tf = |aim - p0| / V_max
    Tf = max(norm(target_init - p0) / Vmx, 1);
    for it = 1:30
        aim = target_model(Tf, target_init, target_vel);
        Tf  = max(norm(aim - p0) / Vmx, 1);
    end
    aim = target_model(Tf, target_init, target_vel);
    d   = aim - p0;
    chi_aim   = atan2(d(2), d(1));
    gamma_aim = atan2(d(3), sqrt(d(1)^2 + d(2)^2));
    gamma_aim = max(-params.gamma_max, min(params.gamma_max, gamma_aim));

    % 控制律: 以最大速率加速到 V_max, 以最大速率转向到碰撞航向, gamma 趋向 gamma_aim
    Vdmx  = params.V_dot_max;
    Cdmx  = params.chi_dot_max;
    Gdmx  = params.gamma_dot_max;
    ctrl = @(x) [ ...
        Cdmx * tanh((chi_aim   - x(5)) / max(Cdmx,1e-6)); ...
        Gdmx * tanh((gamma_aim - x(6)) / max(Gdmx,1e-6)); ...
        Vdmx * (double(x(4) < Vmx - 1e-6)) - Vdmx * (double(x(4) > Vmx + 1e-6))];

    % RK4 积分, 每段 nsub 子步
    h    = Tf / N;
    nsub = 20;
    dt   = h / nsub;
    states = zeros(6, N+1);
    ctrls  = zeros(3, N+1);
    x = x0;
    t = 0;
    states(:,1) = x;
    ctrls(:,1)  = u0;          % 首节点控制固定为 u0 (满足初始等式约束)
    for k = 1:N
        for s = 1:nsub
            u  = ctrl(x);
            k1 = dynamics_model(x,         u, params);
            k2 = dynamics_model(x+0.5*dt*k1, u, params);
            k3 = dynamics_model(x+0.5*dt*k2, u, params);
            k4 = dynamics_model(x+dt*k3,     u, params);
            x  = x + dt/6*(k1 + 2*k2 + 2*k3 + k4);
            t  = t + dt;
        end
        states(:,k+1) = x;
        ctrls(:,k+1)  = ctrl(x);
    end
    % 保证首节点严格等于 x0 (满足初始等式约束)
    states(:,1) = x0;
    ctrls(:,1)  = u0;

    Z0 = zeros(nZ, 1);
    for k = 0:N
        Z0(9*k+1 : 9*k+6) = states(:, k+1);
        Z0(9*k+7 : 9*k+9) = ctrls(:,  k+1);
    end
    Z0(end) = Tf;
end
