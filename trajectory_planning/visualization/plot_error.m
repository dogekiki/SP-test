function fig = plot_error(results, traj_ref)
%PLOT_ERROR 轨迹跟踪误差可视化
%   fig = plot_error(results, traj_ref)
%
%   上子图: 位置误差 dx/dy/dz 随时间
%   下子图: 速度和角度误差 dV/dchi/dgamma 随时间
%
%   使用 interp1 将基准轨迹插值到实际时间点
%
% 输入:
%   results  - simulate 返回的仿真结果结构体
%   traj_ref - 基准轨迹 [6 x M], 每列一个时间步
%
% 输出:
%   fig - figure 句柄

    t_actual = results.t;
    states   = results.states;

    %% 插值基准轨迹到实际时间点
    %  基准轨迹时间轴: linspace(0, Tf, M)
    M = size(traj_ref, 2);
    if isfield(results, 'Tf') && results.Tf > 0
        t_ref = linspace(0, results.Tf, M);
    else
        t_ref = linspace(0, t_actual(end), M);
    end

    % 将查询点限制在基准时间范围内, 避免 NaN
    t_query = t_actual;
    t_query(t_query < t_ref(1))   = t_ref(1);
    t_query(t_query > t_ref(end)) = t_ref(end);

    % 逐行插值 (每行对应一个状态分量)
    traj_ref_interp = zeros(6, numel(t_query));
    for i = 1:6
        traj_ref_interp(i, :) = interp1(t_ref, traj_ref(i, :), t_query, 'linear');
    end

    %% 计算误差
    error = states - traj_ref_interp;

    % 航向角误差 wrap 到 [-pi, pi]
    error(5, :) = mod(error(5, :) + pi, 2*pi) - pi;

    fig = figure;

    %% 上子图: 位置误差
    subplot(2, 1, 1);
    hold on; grid on;
    plot(t_actual, error(1, :), 'r-', 'LineWidth', 1.2, 'DisplayName', 'dx');
    plot(t_actual, error(2, :), 'g-', 'LineWidth', 1.2, 'DisplayName', 'dy');
    plot(t_actual, error(3, :), 'b-', 'LineWidth', 1.2, 'DisplayName', 'dz');
    xlabel('时间 [s]'); ylabel('位置误差 [m]');
    title('位置跟踪误差');
    legend('Location', 'best');
    hold off;

    %% 下子图: 速度和角度误差
    subplot(2, 1, 2);
    hold on; grid on;
    yyaxis left;
    plot(t_actual, error(4, :), 'k-', 'LineWidth', 1.2, 'DisplayName', 'dV [m/s]');
    ylabel('速度误差 [m/s]');
    yyaxis right;
    plot(t_actual, error(5, :), 'm-', 'LineWidth', 1.2, 'DisplayName', 'd\chi [rad]');
    plot(t_actual, error(6, :), 'c-', 'LineWidth', 1.2, 'DisplayName', 'd\gamma [rad]');
    ylabel('角度误差 [rad]');
    xlabel('时间 [s]');
    title('速度与角度跟踪误差');
    legend('Location', 'best');
    hold off;
end
