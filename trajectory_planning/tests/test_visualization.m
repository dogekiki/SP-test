function test_visualization
%TEST_VISUALIZATION 测试可视化模块
%   构造模拟 results, 验证三个绘图函数返回有效 figure 句柄
%   使用 set(0,'DefaultFigureVisible','off') 避免弹窗

    p = params();

    %% 关闭图窗弹窗
    set(0, 'DefaultFigureVisible', 'off');

    %% 构造模拟 results
    N = 101;
    t = linspace(0, 10, N)';
    % 飞行器: 从 (0,0,1000) 匀速飞向 (500,100,1000)
    states = zeros(6, N);
    states(1, :) = linspace(0,   500, N);
    states(2, :) = linspace(0,   100, N);
    states(3, :) = 1000;
    states(4, :) = 50;
    states(5, :) = atan2(100, 500);
    states(6, :) = 0;
    % 控制全零 (匀速直线)
    controls = zeros(3, N);
    % 目标: 从 (300,50,1000) 匀速飞向 (500,100,1000)
    target_states = zeros(3, N);
    target_states(1, :) = linspace(300, 500, N);
    target_states(2, :) = linspace(50,  100, N);
    target_states(3, :) = 1000;

    results = struct();
    results.t              = t;
    results.states         = states;
    results.controls       = controls;
    results.target_states  = target_states;
    results.intercepted    = true;
    results.intercept_dist = 50;
    results.Tf             = 10;
    results.ocp_info       = struct('exitflag', 1, 'cost', 10, 'iterations', 5);

    % 构造基准轨迹 (略偏移的实际轨迹作为参考)
    traj_ref = states + [10*ones(1,N); -5*ones(1,N); 2*ones(1,N); ...
                         1*ones(1,N); 0.02*ones(1,N); 0.01*ones(1,N)];

    %% 测试1: plot_trajectory
    figure; fig1 = plot_trajectory(results);
    assert(isa(fig1, 'matlab.ui.Figure') || ishandle(fig1), ...
        'plot_trajectory 应返回有效 figure 句柄');
    assert(isgraphics(fig1), 'plot_trajectory 返回的句柄应为有效图形对象');
    fprintf('  [plot_trajectory] figure 句柄有效 [PASS]\n');

    %% 测试2: plot_comparison
    figure; fig2 = plot_comparison(results, traj_ref);
    assert(isa(fig2, 'matlab.ui.Figure') || ishandle(fig2), ...
        'plot_comparison 应返回有效 figure 句柄');
    assert(isgraphics(fig2), 'plot_comparison 返回的句柄应为有效图形对象');
    % 验证有两个子图
    ax_children = findall(fig2, 'Type', 'axes');
    assert(numel(ax_children) >= 2, ...
        sprintf('plot_comparison 应有 >=2 个子图, 实际 %d', numel(ax_children)));
    fprintf('  [plot_comparison] figure 句柄有效, 子图数=%d [PASS]\n', numel(ax_children));

    %% 测试3: plot_error
    figure; fig3 = plot_error(results, traj_ref);
    assert(isa(fig3, 'matlab.ui.Figure') || ishandle(fig3), ...
        'plot_error 应返回有效 figure 句柄');
    assert(isgraphics(fig3), 'plot_error 返回的句柄应为有效图形对象');
    ax_children3 = findall(fig3, 'Type', 'axes');
    assert(numel(ax_children3) >= 2, ...
        sprintf('plot_error 应有 >=2 个子图, 实际 %d', numel(ax_children3)));
    fprintf('  [plot_error] figure 句柄有效, 子图数=%d [PASS]\n', numel(ax_children3));

    %% 测试4: plot_trajectory 未拦截场景
    results.intercepted = false;
    results.intercept_dist = 150;
    figure; fig4 = plot_trajectory(results);
    assert(isgraphics(fig4), 'plot_trajectory (未拦截) 应返回有效 figure 句柄');
    fprintf('  [plot_trajectory] 未拦截场景 [PASS]\n');

    %% 测试5: plot_comparison 传空 traj_ref
    figure; fig5 = plot_comparison(results, []);
    assert(isgraphics(fig5), 'plot_comparison (空 traj_ref) 应返回有效 figure 句柄');
    fprintf('  [plot_comparison] 空 traj_ref 场景 [PASS]\n');

    %% 关闭所有图窗并恢复显示
    close all;
    set(0, 'DefaultFigureVisible', 'on');

    fprintf('test_visualization PASSED\n');
end
