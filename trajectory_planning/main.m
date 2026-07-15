% MAIN 固定翼飞行器 3D 动态目标拦截 - 主入口脚本
%   离线 OCP 规划 + MPC 在线修正闭环仿真 + 可视化

clear; clc; close all;
addpath('config','dynamics','ocp','mpc','simulation','visualization');

p = params();
x0 = [0; 0; 1000; 50; 0; 0];
u0 = [0; 0; 0];
target_init = [5000; 1000; 1000];
target_vel  = [30; 10; 0];

fprintf('=== 固定翼飞行器 3D 动态目标拦截 ===\n');
results = simulate(x0, u0, target_init, target_vel, p);
fprintf('拦截成功: %d\n', results.intercepted);
fprintf('拦截距离: %.2f m\n', results.intercept_dist);
fprintf('仿真时间: %.2f s\n', results.t(end));

figure(1); plot_trajectory(results);
figure(2); plot_comparison(results, results.states);
figure(3); plot_error(results, results.states);
