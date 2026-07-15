function test_simulate
%TEST_SIMULATE 测试 RK4 积分器与仿真主循环
%   1. RK4: 匀速直线积分精度验证
%   2. simulate: 字段完整性与基本功能验证
%
% 注意: simulate 内部求解 OCP, 可能需要 30-90 秒

    p = params();

    %% ========== 测试1: RK4 积分器 ==========
    % 匀速直线: x=[0;0;1000;50;0;0], u=[0;0;0], dt=0.1
    % dV=u(3)=0 => V 不变; dx=V*cos(0)*cos(0)=50
    % x_next(1) = 0 + 0.1 * 50 = 5.0
    x  = [0; 0; 1000; 50; 0; 0];
    u  = [0; 0; 0];
    dt = 0.1;
    x_next = integrator(x, u, dt, p);

    % 验证维度
    assert(isequal(size(x_next), [6, 1]), ...
        sprintf('x_next 应为 6x1, 实际 [%d,%d]', size(x_next)));

    % 验证 x 位置: x_next(1) ≈ 5.0
    assert(abs(x_next(1) - 5.0) < 1e-10, ...
        sprintf('x_next(1) 应 ≈ 5.0, 实际 %.10f', x_next(1)));

    % 验证速度不变: x_next(4) = 50
    assert(abs(x_next(4) - 50) < 1e-10, ...
        sprintf('x_next(4) 应 = 50, 实际 %.10f', x_next(4)));

    % 验证 y, z 不变
    assert(abs(x_next(2) - 0) < 1e-10, sprintf('x_next(2) 应 = 0, 实际 %.10f', x_next(2)));
    assert(abs(x_next(3) - 1000) < 1e-10, sprintf('x_next(3) 应 = 1000, 实际 %.10f', x_next(3)));

    fprintf('  [integrator] x_next(1)=%.6f (期望 5.0), V=%.1f [PASS]\n', x_next(1), x_next(4));

    %% ========== 测试2: RK4 与解析解对比 (加速场景) ==========
    % u=[0;0;5] (V_dot=5), V0=50, dt=0.1 => V_next = 50 + 0.1*5 = 50.5
    x  = [0; 0; 1000; 50; 0; 0];
    u  = [0; 0; 5];
    x_next = integrator(x, u, dt, p);
    assert(abs(x_next(4) - 50.5) < 1e-10, ...
        sprintf('加速场景 V_next 应 = 50.5, 实际 %.10f', x_next(4)));
    fprintf('  [integrator] 加速场景 V_next=%.6f (期望 50.5) [PASS]\n', x_next(4));

    %% ========== 测试3: 仿真主循环 ==========
    fprintf('  [simulate] 开始仿真 (可能需要 30-90 秒)...\n');
    x0 = [0; 0; 1000; 50; 0; 0];
    u0 = [0; 0; 0];
    target_init = [3000; 500; 1000];
    target_vel  = [30; 0; 0];

    tic;
    results = simulate(x0, u0, target_init, target_vel, p);
    elapsed = toc;
    fprintf('  [simulate] 仿真完成, 耗时=%.1f s\n', elapsed);

    % 验证字段存在
    required_fields = {'t', 'states', 'controls', 'target_states', ...
                       'intercepted', 'intercept_dist', 'Tf', 'ocp_info'};
    for i = 1:numel(required_fields)
        assert(isfield(results, required_fields{i}), ...
            sprintf('results 缺少字段: %s', required_fields{i}));
    end
    fprintf('  [simulate] 所有必需字段存在 [PASS]\n');

    % 验证 t 是列向量且长度 > 1
    assert(isvector(results.t) && size(results.t, 2) == 1, ...
        sprintf('t 应为列向量, 实际 [%d,%d]', size(results.t)));
    assert(length(results.t) > 1, ...
        sprintf('length(t) 应 > 1, 实际 %d', length(results.t)));

    % 验证 states 维度 [6 x T]
    T = length(results.t);
    assert(isequal(size(results.states), [6, T]), ...
        sprintf('states 应为 [6,%d], 实际 [%d,%d]', T, size(results.states)));
    assert(isequal(size(results.controls), [3, T]), ...
        sprintf('controls 应为 [3,%d], 实际 [%d,%d]', T, size(results.controls)));
    assert(isequal(size(results.target_states), [3, T]), ...
        sprintf('target_states 应为 [3,%d], 实际 [%d,%d]', T, size(results.target_states)));

    % 验证 intercepted 是逻辑值
    assert(islogical(results.intercepted) || isnumeric(results.intercepted), ...
        'intercepted 应为逻辑值或数值');

    % 验证 intercept_dist 是有限值 (拦截时) 或 Inf (未拦截)
    if results.intercepted
        assert(isfinite(results.intercept_dist), '拦截时 intercept_dist 应为有限值');
        assert(results.intercept_dist <= p.d_capture, ...
            sprintf('拦截距离应 <= d_capture=%g, 实际 %g', p.d_capture, results.intercept_dist));
    end

    % 验证 Tf > 0
    assert(results.Tf > 0, sprintf('Tf 应 > 0, 实际 %g', results.Tf));

    % 验证速度全程在 [V_min, V_max]
    V_all = results.states(4, :);
    assert(min(V_all) >= p.V_min - 1e-4 && max(V_all) <= p.V_max + 1e-4, ...
        sprintf('速度约束违反: V 范围 [%.4f, %.4f], 允许 [%g, %g]', ...
            min(V_all), max(V_all), p.V_min, p.V_max));

    fprintf('  [simulate] 维度/字段/约束验证 [PASS]\n');
    fprintf('  [simulate] 拦截=%d, dist=%.2f, t_end=%.2f, Tf=%.2f\n', ...
        results.intercepted, results.intercept_dist, results.t(end), results.Tf);

    fprintf('test_simulate PASSED\n');
end
