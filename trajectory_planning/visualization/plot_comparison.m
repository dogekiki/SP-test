function fig = plot_comparison(results, traj_ref)
%PLOT_COMPARISON 基准轨迹与实际轨迹对比
%   fig = plot_comparison(results, traj_ref)
%
%   上子图: 3D 对比 (基准绿虚线 vs 实际蓝实线)
%   下子图: 距离随时间变化, yline 标注捕获半径
%
% 输入:
%   results  - simulate 返回的仿真结果结构体
%   traj_ref - 基准轨迹 [6 x M], 每列一个时间步 (可为 OCP 参考或实际轨迹)
%
% 输出:
%   fig - figure 句柄

    p = params();

    fig = figure;

    %% 上子图: 3D 对比
    subplot(2, 1, 1);
    hold on; grid on;

    % 实际轨迹 (蓝实线)
    ac_pos = results.states(1:3, :);
    plot3(ac_pos(1,:), ac_pos(2,:), ac_pos(3,:), 'b-', 'LineWidth', 1.5, ...
        'DisplayName', '实际轨迹');

    % 基准轨迹 (绿虚线)
    if ~isempty(traj_ref) && size(traj_ref, 1) >= 3
        ref_pos = traj_ref(1:3, :);
        plot3(ref_pos(1,:), ref_pos(2,:), ref_pos(3,:), 'g--', 'LineWidth', 1.5, ...
            'DisplayName', '基准轨迹');
    end

    xlabel('X [m]'); ylabel('Y [m]'); zlabel('Z [m]');
    title('基准轨迹 vs 实际轨迹');
    legend('Location', 'best');
    view(30, 25);
    hold off;

    %% 下子图: 距离随时间变化
    subplot(2, 1, 2);
    hold on; grid on;

    dist = sqrt(sum((results.states(1:3,:) - results.target_states).^2, 1));
    plot(results.t, dist, 'b-', 'LineWidth', 1.5);
    yline(p.d_capture, 'r--', 'LineWidth', 1, 'Label', ...
        sprintf('捕获半径=%g m', p.d_capture));

    xlabel('时间 [s]'); ylabel('距离 [m]');
    title('飞行器-目标距离随时间变化');
    hold off;
end
