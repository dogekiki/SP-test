function cfg = config()
    % 飞行器参数
    cfg.aircraft.m = 25;          % 质量 [kg]
    cfg.aircraft.S = 0.5;         % 参考面积 [m^2]
    cfg.aircraft.rho = 1.225;     % 空气密度 [kg/m^3]
    cfg.aircraft.g = 9.81;        % 重力加速度 [m/s^2]
    cfg.aircraft.CD0 = 0.02;      % 零升阻力系数
    
    % MPC参数
    cfg.mpc.N = 20;               % 预测时域
    cfg.mpc.dt = 0.1;             % 采样时间 [s]
    cfg.mpc.Q = diag([10,10,10,1,5,5]);  % 状态权重
    cfg.mpc.R = diag([0.1,1,1]);          % 控制权重
    cfg.mpc.P = [];               % 终端权重(自动计算DARE)
    
    % 约束
    cfg.constraints.T_min = 10;   cfg.constraints.T_max = 200;
    cfg.constraints.V_min = 15;   cfg.constraints.V_max = 50;
    cfg.constraints.chi_dot_max = 0.3;
    cfg.constraints.gamma_dot_max = 0.2;
    
    % 软约束fallback权重
    cfg.soft.w_collision = 1000;
    cfg.soft.w_tracking = 100;
    cfg.soft.w_energy = 10;
    
    % 编队参数
    cfg.formation.n_drones = 3;
    cfg.formation.offsets = [0, 0, 0;        % Leader (无偏移)
                             0, -50, 0;       % Follower 1
                             0, 50, 0];       % Follower 2
    
    % 仿真参数
    cfg.sim.T_total = 60;         % 仿真时长 [s]
    cfg.sim.wind_speed = 5;       % 常值风速 [m/s]
    cfg.sim.wind_direction = 45;  % 风向 [deg]
end
