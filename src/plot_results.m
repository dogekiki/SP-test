function plot_results(data, cfg, save_dir)
    if nargin < 3, save_dir = 'results'; end
    if ~exist(save_dir, 'dir'), mkdir(save_dir); end
    
    % 图1: 3D轨迹
    figure('Position', [100, 100, 800, 600]);
    plot3(data.x_ref(1,:), data.x_ref(2,:), data.x_ref(3,:), 'b--', 'LineWidth', 2); hold on;
    plot3(data.x_history(1,:), data.x_history(2,:), data.x_history(3,:), 'r-', 'LineWidth', 2);
    if isfield(data, 'x_followers')
        colors = ['g', 'm'];
        for i = 1:min(size(data.x_followers, 3), 2)
            plot3(data.x_followers(1,:,i), data.x_followers(2,:,i), data.x_followers(3,:,i), colors(i), 'LineWidth', 1.5);
        end
    end
    grid on; xlabel('X [m]'); ylabel('Y [m]'); zlabel('Z [m]');
    legend('参考轨迹', 'Leader', 'Follower 1', 'Follower 2', 'Location', 'best');
    title('3D轨迹跟踪');
    saveas(gcf, fullfile(save_dir, 'trajectory_3d.png'));
    
    % 图2: 跟踪误差
    figure('Position', [100, 100, 800, 600]);
    t = 0:cfg.mpc.dt:(length(data.errors)-1)*cfg.mpc.dt;
    plot(t, data.errors, 'LineWidth', 1.5); grid on;
    xlabel('时间 [s]'); ylabel('跟踪误差 [m]');
    title('轨迹跟踪误差');
    saveas(gcf, fullfile(save_dir, 'tracking_error.png'));
    
    % 图3: 求解时间
    figure('Position', [100, 100, 800, 600]);
    plot(t, data.solve_times*1000, 'LineWidth', 1.5); grid on;
    xlabel('时间 [s]'); ylabel('求解时间 [ms]');
    title('MPC求解时间');
    saveas(gcf, fullfile(save_dir, 'solve_time.png'));
end
