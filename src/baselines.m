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
Kp = [0.5, 0.5, 0.5, 0.1, 0.5, 0.5];
Ki = [0.01, 0.01, 0.01, 0.001, 0.01, 0.01];
Kd = [0.1, 0.1, 0.1, 0.01, 0.1, 0.1];
integral_err = zeros(6,1); prev_err = zeros(6,1);

fprintf('PID仿真...\n');
for k = 1:K
    err = x_ref(:,k) - x_pid;
    integral_err = integral_err + err * cfg.mpc.dt;
    deriv_err = (err - prev_err) / cfg.mpc.dt;
    u_pid = Kp.*err + Ki.*integral_err + Kd.*deriv_err;
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

figure('Position',[100,100,800,600]);
t = 0:cfg.mpc.dt:(K-1)*cfg.mpc.dt;
plot(t, err_pid, 'b', 'LineWidth', 1.5); hold on;
plot(t, err_lqr, 'g', 'LineWidth', 1.5);
xlabel('时间 [s]'); ylabel('跟踪误差 [m]'); grid on;
legend('PID', 'LQR', 'Location', 'best'); title('基线控制器跟踪误差');
saveas(gcf, 'results/baseline_comparison.png');

function x_next = rk4(f, x, u, params, dt)
    k1 = f(x, u, params);
    k2 = f(x + 0.5*dt*k1, u, params);
    k3 = f(x + 0.5*dt*k2, u, params);
    k4 = f(x + dt*k3, u, params);
    x_next = x + (dt/6) * (k1 + 2*k2 + 2*k3 + k4);
end
