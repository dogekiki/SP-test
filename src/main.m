% main.m - 单机LTV-MPC轨迹跟踪仿真主程序
clear; clc; close all;
addpath('src');

%% 初始化
cfg = config();
waypoints = [0,    0,   100;
             200,  0,   100;
             200,  200, 120;
             0,    200, 100;
             0,    0,   100];

[x_ref, u_ref] = trajectory_generator(waypoints, cfg);
K = size(x_ref, 2);

%% 仿真主循环
x_current = x_ref(:,1);
x_history = zeros(6, K);
u_history = zeros(3, K);
errors = zeros(1, K);
solve_times = zeros(1, K);

fprintf('开始仿真 (K=%d步, dt=%.2fs, T=%.1fs)\n', K, cfg.mpc.dt, K*cfg.mpc.dt);

for k = 1:K
    k_end = min(k + cfg.mpc.N - 1, K);
    N_actual = k_end - k + 1;
    x_ref_window = x_ref(:, k:k_end);
    u_ref_window = u_ref(:, k:k_end);
    
    if N_actual < cfg.mpc.N
        x_ref_window = [x_ref_window, repmat(x_ref(:,end), 1, cfg.mpc.N - N_actual)];
        u_ref_window = [u_ref_window, repmat(u_ref(:,end), 1, cfg.mpc.N - N_actual)];
    end
    
    [u_opt, info] = mpc_controller(x_current, x_ref_window, u_ref_window, cfg);
    
    x_history(:,k) = x_current;
    u_history(:,k) = u_opt;
    errors(k) = norm(x_current(1:3) - x_ref(1:3,k));
    solve_times(k) = info.solve_time;
    
    x_current = rk4_step(@dynamics_3dof, x_current, u_opt, cfg.aircraft, cfg.mpc.dt);
    
    if mod(k, 50) == 0
        fprintf('  k=%d/%d, error=%.2fm, solve=%.1fms\n', k, K, errors(k), solve_times(k)*1000);
    end
end

fprintf('\n=== 仿真结果 ===\n');
fprintf('跟踪误差 RMSE: %.2f m\n', sqrt(mean(errors.^2)));
fprintf('跟踪误差 MAX:  %.2f m\n', max(errors));
fprintf('求解时间 MEAN:  %.2f ms\n', mean(solve_times)*1000);
fprintf('求解时间 MAX:   %.2f ms\n', max(solve_times)*1000);

data.x_ref = x_ref;
data.x_history = x_history;
data.errors = errors;
data.solve_times = solve_times;
plot_results(data, cfg);

fprintf('\n图表已保存到 results/ 目录\n');

function x_next = rk4_step(f, x, u, params, dt)
    k1 = f(x, u, params);
    k2 = f(x + 0.5*dt*k1, u, params);
    k3 = f(x + 0.5*dt*k2, u, params);
    k4 = f(x + dt*k3, u, params);
    x_next = x + (dt/6) * (k1 + 2*k2 + 2*k3 + k4);
end
