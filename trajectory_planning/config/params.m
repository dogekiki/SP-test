function p = params()
%PARAMS 返回飞行器轨迹规划的全局配置参数结构体
%   p = params() 返回包含物理约束、OCP/MPC 参数、权重矩阵和求解器选项的结构体

    %% 物理约束
    p.V_min = 30;              % 最小速度 [m/s]
    p.V_max = 80;              % 最大速度 [m/s]
    p.chi_dot_max = 0.15;      % 最大航向角速率 [rad/s]
    p.gamma_max = 0.35;        % 最大航迹倾斜角 [rad]
    p.gamma_dot_max = 0.10;    % 最大航迹倾斜角速率 [rad/s]
    p.V_dot_max = 5;           % 最大速度变化率 [m/s^2]
    p.z_min = 0;               % 最小高度 [m]

    %% 最小转弯半径
    p.R_min = p.V_min / p.chi_dot_max;  % [m]

    %% 捕获距离
    p.d_capture = 100;         % [m]

    %% OCP (最优控制问题) 参数
    p.N = 40;                  % 配置点数
    p.w_smooth = 0.01;         % 平滑性权重

    %% MPC 参数
    p.Np = 10;                 % 预测时域
    p.Nc = 5;                  % 控制时域
    p.dt_mpc = 0.1;            % MPC 采样时间 [s]
    p.replan_threshold = 0.8;  % 重规划触发阈值
    p.replan_min_interval = 2 * p.Np * p.dt_mpc;  % 最小重规划间隔 [s]

    %% 权重矩阵
    p.Q = diag([10, 10, 10, 1, 1, 1]);   % 状态权重 [6x6]
    p.R = diag([0.1, 0.1, 0.1]);          % 控制权重 [3x3]
    p.P = [];                             % 终端权重（暂为空）

    %% fmincon 求解器选项
    p.fmincon_opts = optimoptions('fmincon', ...
        'Algorithm', 'sqp', ...
        'MaxFunctionEvaluations', 1e4, ...
        'StepTolerance', 1e-8, ...
        'ConstraintTolerance', 1e-6, ...
        'Display', 'iter');

    %% QP 求解器选项
    p.qp_opts = optimoptions('quadprog', ...
        'Display', 'off', ...
        'OptimalityTolerance', 1e-8);
end
