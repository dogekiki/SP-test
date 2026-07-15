function fig = plot_trajectory(results)
%PLOT_TRAJECTORY 3D 轨迹可视化
%   fig = plot_trajectory(results)
%
%   绘制飞行器与目标的 3D 轨迹:
%     - 飞行器轨迹: 蓝色实线
%     - 目标轨迹: 红色虚线
%     - 标注起点和终点 (拦截点)
%     - 标题包含拦截信息
%
% 输入:
%   results - simulate 返回的仿真结果结构体
%
% 输出:
%   fig - figure 句柄

    fig = figure;
    hold on; grid on;

    % 飞行器轨迹 (蓝实线)
    ac_pos = results.states(1:3, :);
    plot3(ac_pos(1,:), ac_pos(2,:), ac_pos(3,:), 'b-', 'LineWidth', 1.5, ...
        'DisplayName', '飞行器');

    % 目标轨迹 (红虚线)
    tgt_pos = results.target_states;
    plot3(tgt_pos(1,:), tgt_pos(2,:), tgt_pos(3,:), 'r--', 'LineWidth', 1.5, ...
        'DisplayName', '目标');

    % 飞行器起点
    plot3(ac_pos(1,1), ac_pos(2,1), ac_pos(3,1), 'bo', ...
        'MarkerSize', 8, 'MarkerFaceColor', 'b', 'HandleVisibility', 'off');
    text(ac_pos(1,1), ac_pos(2,1), ac_pos(3,1), '  起点', 'Color', 'b', 'FontSize', 9);

    % 飞行器终点 / 拦截点
    plot3(ac_pos(1,end), ac_pos(2,end), ac_pos(3,end), 'bs', ...
        'MarkerSize', 8, 'MarkerFaceColor', 'b', 'HandleVisibility', 'off');
    if results.intercepted
        label_end = '  拦截点';
    else
        label_end = '  终点';
    end
    text(ac_pos(1,end), ac_pos(2,end), ac_pos(3,end), label_end, 'Color', 'b', 'FontSize', 9);

    % 目标起点
    plot3(tgt_pos(1,1), tgt_pos(2,1), tgt_pos(3,1), 'ro', ...
        'MarkerSize', 8, 'MarkerFaceColor', 'r', 'HandleVisibility', 'off');

    % 目标终点
    plot3(tgt_pos(1,end), tgt_pos(2,end), tgt_pos(3,end), 'rs', ...
        'MarkerSize', 8, 'MarkerFaceColor', 'r', 'HandleVisibility', 'off');

    xlabel('X [m]'); ylabel('Y [m]'); zlabel('Z [m]');

    if results.intercepted
        title(sprintf('飞行器拦截轨迹 (拦截成功, 距离=%.1f m, 时间=%.1f s)', ...
            results.intercept_dist, results.t(end)));
    else
        title(sprintf('飞行器拦截轨迹 (未拦截, 最终距离=%.1f m, 时间=%.1f s)', ...
            results.intercept_dist, results.t(end)));
    end

    legend('Location', 'best');
    view(30, 25);
    hold off;
end
