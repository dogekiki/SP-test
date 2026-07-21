% formation_main.m - 3机Leader-Follower编队仿真主程序
clear; clc; close all;
addpath('src');

cfg = config();
waypoints = [0,    0,   100;
             200,  0,   100;
             200,  200, 120;
             0,    200, 100;
             0,    0,   100];

[x_ref, u_ref] = trajectory_generator(waypoints, cfg);
K = size(x_ref, 2);

x_leader = x_ref(:,1);
x_f1 = x_leader + [cfg.formation.offsets(2,:)'; 0; 0; 0];
x_f2 = x_leader + [cfg.formation.offsets(3,:)'; 0; 0; 0];
x_all = [x_leader, x_f1, x_f2];

x_history_leader = zeros(6, K);
x_history_followers = zeros(6, K, 2);
formation_errors = zeros(2, K);
solve_times = zeros(1, K);

fprintf('开始编队仿真 (3机, K=%d步)\n', K);

for k = 1:K
    k_end = min(k + cfg.mpc.N - 1, K);
    N_actual = k_end - k + 1;
    x_ref_window = x_ref(:, k:k_end);
    u_ref_window = u_ref(:, k:k_end);
    
    if N_actual < cfg.mpc.N
        x_ref_window = [x_ref_window, repmat(x_ref(:,end), 1, cfg.mpc.N - N_actual)];
        u_ref_window = [u_ref_window, repmat(u_ref(:,end), 1, cfg.mpc.N - N_actual)];
    end
    
    [u_all, info] = formation_controller(x_all, x_ref_window, u_ref_window, cfg);
    
    x_history_leader(:,k) = x_all(:,1);
    x_history_followers(:,k,1) = x_all(:,2);
    x_history_followers(:,k,2) = x_all(:,3);
    
    for i = 1:2
        offset = cfg.formation.offsets(i+1,:)';
        expected_pos = x_all(:,1) + [offset; 0; 0; 0];
        formation_errors(i,k) = norm(x_all(1:3,i+1) - expected_pos(1:3));
    end
    solve_times(k) = info.max_solve_time;
    
    for i = 1:3
        wind = [cfg.sim.wind_speed * cosd(cfg.sim.wind_direction); 
                cfg.sim.wind_speed * sind(cfg.sim.wind_direction); 0];
        x_all(1:3,i) = x_all(1:3,i) + wind * cfg.mpc.dt;
        x_all(:,i) = rk4_step(@dynamics_3dof, x_all(:,i), u_all(:,i), cfg.aircraft, cfg.mpc.dt);
    end
    
    if mod(k, 50) == 0
        fprintf('  k=%d/%d, form_err=[%.1f, %.1f]m, solve=%.1fms\n', k, K, formation_errors(1,k), formation_errors(2,k), solve_times(k)*1000);
    end
end

fprintf('\n=== 编队仿真结果 ===\n');
fprintf('Follower1 编队误差 RMSE: %.2f m\n', sqrt(mean(formation_errors(1,:).^2)));
fprintf('Follower2 编队误差 RMSE: %.2f m\n', sqrt(mean(formation_errors(2,:).^2)));
fprintf('最大求解时间: %.2f ms\n', max(solve_times)*1000);

data.x_ref = x_ref;
data.x_history = x_history_leader;
data.x_followers = x_history_followers;
data.errors = formation_errors(1,:);
data.solve_times = solve_times;
plot_results(data, cfg, 'results/formation');

fprintf('\n图表已保存到 results/formation/ 目录\n');

function x_next = rk4_step(f, x, u, params, dt)
    k1 = f(x, u, params);
    k2 = f(x + 0.5*dt*k1, u, params);
    k3 = f(x + 0.5*dt*k2, u, params);
    k4 = f(x + dt*k3, u, params);
    x_next = x + (dt/6) * (k1 + 2*k2 + 2*k3 + k4);
end
