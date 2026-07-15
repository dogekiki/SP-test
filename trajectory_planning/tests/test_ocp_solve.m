function test_ocp_solve
%TEST_OCP_SOLVE 测试 OCP 主求解函数 plan_offline_OCP.m
%   验证: exitflag>0; 轨迹维度; 初始状态/控制匹配; 终端拦截; 速度/控制约束全程满足
%
% 注意: fmincon 求解可能需要 30-90 秒

    p = params();
    N = p.N;

    fprintf('  [test_ocp_solve] 求解中 (可能需要 30-90 秒)...\n');

    x0 = [0; 0; 1000; 50; 0; 0];
    u0 = [0; 0; 0];
    target_init = [5000; 1000; 1000];
    target_vel  = [30; 0; 0];

    tic;
    [traj_ref, ctrl_ref, Tf, info] = plan_offline_OCP(x0, u0, target_init, target_vel, p);
    elapsed = toc;
    fprintf('  [test_ocp_solve] 求解完成: exitflag=%d, cost=%.4f, iter=%d, 耗时=%.1fs\n', ...
        info.exitflag, info.cost, info.iterations, elapsed);

    %% 测试1: exitflag > 0 (求解成功)
    assert(info.exitflag > 0, ...
        'fmincon 应成功求解 (exitflag>0), 实际 exitflag=%d', info.exitflag);

    %% 测试2: 轨迹维度正确
    assert(isequal(size(traj_ref), [6, N+1]), ...
        'traj_ref 维度应为 [6, N+1]=[%d,%d], 实际 [%d,%d]', 6, N+1, size(traj_ref));
    assert(isequal(size(ctrl_ref), [3, N+1]), ...
        'ctrl_ref 维度应为 [3, N+1]=[%d,%d], 实际 [%d,%d]', 3, N+1, size(ctrl_ref));

    %% 测试3: 初始状态/控制匹配
    assert(max(abs(traj_ref(:,1) - x0)) < 1e-6, ...
        '初始状态应匹配 x0, 误差=%g', max(abs(traj_ref(:,1) - x0)));
    assert(max(abs(ctrl_ref(:,1) - u0)) < 1e-6, ...
        '初始控制应匹配 u0, 误差=%g', max(abs(ctrl_ref(:,1) - u0)));

    %% 测试4: 终端拦截距离 <= d_capture
    p_N = traj_ref(1:3, end);
    p_tgt = target_model(Tf, target_init, target_vel);
    dist_end = norm(p_N - p_tgt);
    fprintf('  [test_ocp_solve] 终端拦截距离=%.4f m (d_capture=%g m)\n', dist_end, p.d_capture);
    assert(dist_end <= p.d_capture + 1e-3, ...
        '终端拦截距离应 <= d_capture=%g, 实际=%g', p.d_capture, dist_end);

    %% 测试5: 速度约束全程满足 V in [V_min, V_max]
    V_all = traj_ref(4, :);
    assert(min(V_all) >= p.V_min - 1e-4 && max(V_all) <= p.V_max + 1e-4, ...
        '速度约束违反: V 范围 [%.4f, %.4f], 允许 [%g, %g]', ...
        min(V_all), max(V_all), p.V_min, p.V_max);

    %% 测试6: 航迹角约束 |gamma| <= gamma_max
    gamma_all = traj_ref(6, :);
    assert(max(abs(gamma_all)) <= p.gamma_max + 1e-4, ...
        '航迹角约束违反: max|gamma|=%.6f > %g', max(abs(gamma_all)), p.gamma_max);

    %% 测试7: 控制约束全程满足
    chi_dot_all   = ctrl_ref(1, :);
    gamma_dot_all = ctrl_ref(2, :);
    V_dot_all     = ctrl_ref(3, :);
    assert(max(abs(chi_dot_all))   <= p.chi_dot_max   + 1e-4, 'chi_dot 约束违反');
    assert(max(abs(gamma_dot_all)) <= p.gamma_dot_max + 1e-4, 'gamma_dot 约束违反');
    assert(max(abs(V_dot_all))     <= p.V_dot_max     + 1e-4, 'V_dot 约束违反');

    %% 测试8: 配点缺陷接近 0 (动力学一致性)
    Z = zeros(9*(N+1)+1, 1);
    for k = 0:N
        Z(9*k+1:9*k+6) = traj_ref(:, k+1);
        Z(9*k+7:9*k+9) = ctrl_ref(:, k+1);
    end
    Z(end) = Tf;
    defects = ocp_collocation(Z, p);
    fprintf('  [test_ocp_solve] 最大配点缺陷=%g\n', max(abs(defects)));
    assert(max(abs(defects)) < 1e-4, ...
        '求解轨迹配点缺陷过大: max=%g', max(abs(defects)));

    fprintf('test_ocp_solve PASSED (Tf=%.3f, cost=%.4f, exitflag=%d, dist_end=%.4f)\n', ...
        Tf, info.cost, info.exitflag, dist_end);
end
