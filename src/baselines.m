% baselines.m - PID和LQR基线控制器仿真
clear; clc; close all;
addpath('src');

cfg = config();
waypoints = [0, 0, 100; 200, 0, 100; 200, 200, 120; 0, 200, 100; 0, 0, 100];
[x_ref, u_ref] = trajectory_generator(waypoints, cfg);
K = size(x_ref, 2);

%% PID控制器
x_pid = x_ref(:,1);
x_hist_pid = zeros(6,K); err_pid = zeros(1,K);
% PID增益: 3×6矩阵 (3控制 ← 6状态误差)
% 状态: [px, py, pz, V, chi, gamma], 控制: [T, chi_dot, gamma_dot]
Kp = [0,    0,    0.5,  2.0,  0,    0;      % T ← pz, V误差
      0.5,  0.5,  0,    0,    1.0,  0;      % chi_dot ← px, py, chi误差
      0,    0,    0.5,  0,    0,    1.0];   % gamma_dot ← pz, gamma误差
Ki = [0,    0,    0.01, 0.1,  0,    0;
      0.01, 0.01, 0,    0,    0.1,  0;
      0,    0,    0.01, 0,    0,    0.1];
Kd = [0,    0,    0.1,  0.5,  0,    0;
      0.1,  0.1,  0,    0,    0.2,  0;
      0,    0,    0.1,  0,    0,    0.2];
integral_err = zeros(6,1); prev_err = zeros(6,1);

fprintf('PID仿真...\n');
for k = 1:K
    err = x_ref(:,k) - x_pid;
    err(5) = wrapToPi(err(5));  % 航向角误差归一化
    err(6) = wrapToPi(err(6));  % 航迹角误差归一化
    integral_err = integral_err + err * cfg.mpc.dt;
    deriv_err = (err - prev_err) / cfg.mpc.dt;
    u_pid = u_ref(:,k) + Kp * err + Ki * integral_err + Kd * deriv_err;  % 含前馈
    u_pid(1) = max(cfg.constraints.T_min, min(cfg.constraints.T_max, u_pid(1)));
    u_pid(2) = max(-cfg.constraints.chi_dot_max, min(cfg.constraints.chi_dot_max, u_pid(2)));
    u_pid(3) = max(-cfg.constraints.gamma_dot_max, min(cfg.constraints.gamma_dot_max, u_pid(3)));
    x_hist_pid(:,k) = x_pid; err_pid(k) = norm(err(1:3));
    x_pid = rk4(@dynamics_3dof, x_pid, u_pid, cfg.aircraft, cfg.mpc.dt);
    prev_err = err;
end

%% LQR控制器
x_lqr = x_ref(:,1);
x_hist_lqr = zeros(6,K); err_lqr = zeros(1,K);
A_avg = zeros(6); B_avg = zeros(6,3);
cnt = 0;
for k = 1:10:min(K,100)
    [A,B] = ltv_linearize(x_ref(:,k), u_ref(:,k), cfg.aircraft, cfg.mpc.dt);
    A_avg = A_avg + A; B_avg = B_avg + B; cnt = cnt + 1;
end
A_avg = A_avg/cnt; B_avg = B_avg/cnt;
K_lqr = lqr(A_avg, B_avg, cfg.mpc.Q, cfg.mpc.R);

fprintf('LQR仿真...\n');
for k = 1:K
    err = x_ref(:,k) - x_lqr;
    err(5) = wrapToPi(err(5));  % 航向角误差归一化
    err(6) = wrapToPi(err(6));  % 航迹角误差归一化
    u_lqr = u_ref(:,k) + K_lqr * err;
    u_lqr(1) = max(cfg.constraints.T_min, min(cfg.constraints.T_max, u_lqr(1)));
    u_lqr(2) = max(-cfg.constraints.chi_dot_max, min(cfg.constraints.chi_dot_max, u_lqr(2)));
    u_lqr(3) = max(-cfg.constraints.gamma_dot_max, min(cfg.constraints.gamma_dot_max, u_lqr(3)));
    x_hist_lqr(:,k) = x_lqr; err_lqr(k) = norm(err(1:3));
    x_lqr = rk4(@dynamics_3dof, x_lqr, u_lqr, cfg.aircraft, cfg.mpc.dt);
end

fprintf('\n=== 基线对比 ===\n');
fprintf('PID  RMSE: %.2f m\n', sqrt(mean(err_pid.^2)));
fprintf('LQR  RMSE: %.2f m\n', sqrt(mean(err_lqr.^2)));

%% MPC控制器 (复用)
x_mpc = x_ref(:,1);
x_hist_mpc = zeros(6,K); err_mpc = zeros(1,K);
fprintf('MPC仿真...\n');
for k = 1:K
    k_end = min(k + cfg.mpc.N - 1, K);
    x_ref_window = x_ref(:, k:k_end);
    u_ref_window = u_ref(:, k:k_end);
    if k_end - k + 1 < cfg.mpc.N
        x_ref_window = [x_ref_window, repmat(x_ref(:,end), 1, cfg.mpc.N - (k_end-k+1))];
        u_ref_window = [u_ref_window, repmat(u_ref(:,end), 1, cfg.mpc.N - (k_end-k+1))];
    end
    [u_mpc, ~] = mpc_controller(x_mpc, x_ref_window, u_ref_window, cfg);
    x_hist_mpc(:,k) = x_mpc; err_mpc(k) = norm(x_mpc(1:3) - x_ref(1:3,k));
    x_mpc = rk4(@dynamics_3dof, x_mpc, u_mpc, cfg.aircraft, cfg.mpc.dt);
end
fprintf('MPC  RMSE: %.2f m\n', sqrt(mean(err_mpc.^2)));

fprintf('\n=== 总结 ===\n');
fprintf('MPC  RMSE: %.2f m  (本方法)\n', sqrt(mean(err_mpc.^2)));
fprintf('LQR  RMSE: %.2f m  (基线)\n', sqrt(mean(err_lqr.^2)));
fprintf('PID  RMSE: %.2f m  (基线)\n', sqrt(mean(err_pid.^2)));

figure('Position',[100,100,800,600]);
t = 0:cfg.mpc.dt:(K-1)*cfg.mpc.dt;
plot(t, err_mpc, 'r', 'LineWidth', 2); hold on;
plot(t, err_lqr, 'g', 'LineWidth', 1.5);
plot(t, err_pid, 'b', 'LineWidth', 1.5);
xlabel('时间 [s]'); ylabel('跟踪误差 [m]'); grid on;
legend('MPC (本方法)', 'LQR', 'PID', 'Location', 'best'); title('控制器对比: 轨迹跟踪误差');
saveas(gcf, 'results/baseline_comparison.png');

function x_next = rk4(f, x, u, params, dt)
    k1 = f(x, u, params);
    k2 = f(x + 0.5*dt*k1, u, params);
    k3 = f(x + 0.5*dt*k2, u, params);
    k4 = f(x + dt*k3, u, params);
    x_next = x + (dt/6) * (k1 + 2*k2 + 2*k3 + k4);
end
