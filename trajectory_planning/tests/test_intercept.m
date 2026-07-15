function test_intercept
%TEST_INTERCEPT 端到端拦截测试
%   验证完整仿真流程: OCP + MPC + RK4 闭环仿真能否成功拦截动态目标
%
% 测试场景:
%   x0=[0;0;1000;50;0;0], u0=[0;0;0]
%   target_init=[5000;1000;1000], target_vel=[30;10;0]
%
% 验证:
%   1. results.intercepted == true
%   2. intercept_dist <= d_capture
%   3. t(end) > 0
%   4. t(end) < 300
%   5. 速度全程在 [V_min, V_max]
%
% 注意: OCP 求解 + MPC 循环可能需要 1-5 分钟

    p = params();

    x0 = [0; 0; 1000; 50; 0; 0];
    u0 = [0; 0; 0];
    target_init = [5000; 1000; 1000];
    target_vel  = [30; 10; 0];

    fprintf('  [test_intercept] 开始端到端仿真 (可能需要 1-5 分钟)...\n');
    tic;
    results = simulate(x0, u0, target_init, target_vel, p);
    elapsed = toc;
    fprintf('  [test_intercept] 仿真完成, 耗时=%.1f s\n', elapsed);

    %% 测试1: 拦截成功
    assert(results.intercepted == true, ...
        sprintf('应拦截成功, 实际 intercepted=%d', results.intercepted));
    fprintf('  [test_intercept] 拦截成功 [PASS]\n');

    %% 测试2: 拦截距离 <= d_capture
    assert(results.intercept_dist <= p.d_capture, ...
        sprintf('拦截距离应 <= d_capture=%g, 实际=%g', p.d_capture, results.intercept_dist));
    fprintf('  [test_intercept] 拦截距离=%.2f m <= d_capture=%g m [PASS]\n', ...
        results.intercept_dist, p.d_capture);

    %% 测试3: 仿真时间 > 0
    assert(results.t(end) > 0, ...
        sprintf('仿真时间应 > 0, 实际 t(end)=%g', results.t(end)));
    fprintf('  [test_intercept] 仿真时间=%.2f s > 0 [PASS]\n', results.t(end));

    %% 测试4: 仿真时间 < 300
    assert(results.t(end) < 300, ...
        sprintf('仿真时间应 < 300, 实际 t(end)=%g', results.t(end)));
    fprintf('  [test_intercept] 仿真时间=%.2f s < 300 [PASS]\n', results.t(end));

    %% 测试5: 速度全程在 [V_min, V_max]
    V_all = results.states(4, :);
    V_min_actual = min(V_all);
    V_max_actual = max(V_all);
    assert(V_min_actual >= p.V_min - 1e-4 && V_max_actual <= p.V_max + 1e-4, ...
        sprintf('速度约束违反: V 范围 [%.4f, %.4f], 允许 [%g, %g]', ...
            V_min_actual, V_max_actual, p.V_min, p.V_max));
    fprintf('  [test_intercept] 速度范围 [%.2f, %.2f] m/s 在 [%g, %g] 内 [PASS]\n', ...
        V_min_actual, V_max_actual, p.V_min, p.V_max);

    fprintf('  [test_intercept] 拦截时间=%.2f s, 距离=%.2f m, OCP Tf=%.2f s, 耗时=%.1f s\n', ...
        results.t(end), results.intercept_dist, results.Tf, elapsed);

    fprintf('test_intercept PASSED\n');
end
