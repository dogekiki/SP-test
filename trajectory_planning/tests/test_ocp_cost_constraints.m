function test_ocp_cost_constraints
%TEST_OCP_COST_CONSTRAINTS 测试 OCP 代价函数与约束
%   验证: J≈Tf (控制全零); ceq 维度; c 行数; 动力学缺陷≈0; 初始约束满足

    p = params();
    N = p.N;

    %% 构造匀速直线轨迹 (V=50, chi=0, gamma=0, 控制全零)
    x0 = [0; 0; 1000; 50; 0; 0];
    u0 = [0; 0; 0];
    Tf = 100;
    V = 50; chi = 0; gamma = 0;
    h = Tf / N;
    f = [V*cos(gamma)*cos(chi); V*cos(gamma)*sin(chi); V*sin(gamma); 0; 0; 0];

    Z = zeros(9*(N+1) + 1, 1);
    for k = 0:N
        xk = x0 + f * (h * k);
        Z(9*k + 1 : 9*k + 6) = xk;
        Z(9*k + 7 : 9*k + 9) = u0;
    end
    Z(end) = Tf;

    target_init = [5000; 1000; 1000];
    target_vel  = [30; 0; 0];

    %% 测试1: 代价函数 J ≈ Tf (控制全零, 平滑项为 0)
    J = ocp_cost(Z, p);
    assert(abs(J - Tf) < 1e-9, ...
        '控制全零时 J 应等于 Tf, J=%g, Tf=%g', J, Tf);

    %% 测试2: 代价函数对非零控制应增加
    Z_u = Z;
    Z_u(7:9) = [0.1; 0.05; 1];   % 给 u0 非零 (但破坏初始约束, 仅测试代价)
    J_u = ocp_cost(Z_u, p);
    assert(J_u > Tf, '非零控制时代价应大于 Tf');

    %% 测试3: 约束函数返回维度
    [c, ceq] = ocp_constraints(Z, x0, u0, target_init, target_vel, p);
    % ceq = 配点缺陷(6N) + 初始状态(6) + 初始控制(3) = 6N + 9
    assert(numel(ceq) == 6*N + 9, ...
        'ceq 维度应为 6N+9 = %d, 实际 %d', 6*N+9, numel(ceq));
    % c = 每节点 6 个 × (N+1) 节点 + 1 终端拦截 = 6(N+1)+1
    assert(numel(c) == 6*(N+1) + 1, ...
        'c 维度应为 6(N+1)+1 = %d, 实际 %d', 6*(N+1)+1, numel(c));

    %% 测试4: 动力学缺陷接近 0 (ceq 前 6N 项)
    defects = ceq(1:6*N);
    assert(max(abs(defects)) < 1e-8, ...
        '匀速直线动力学缺陷应接近 0, max=%g', max(abs(defects)));

    %% 测试5: 初始约束满足 (ceq 后 9 项 ≈ 0)
    init_part = ceq(6*N+1 : end);
    assert(max(abs(init_part)) < 1e-10, ...
        '初始状态/控制约束应满足, max=%g', max(abs(init_part)));

    %% 测试6: 匀速直线满足速度/航迹角/控制不等式约束 (前 6(N+1) 项 c <= 0)
    c_path = c(1:6*(N+1));
    assert(max(c_path) <= 1e-12, ...
        '匀速直线 (V=50, gamma=0, u=0) 应满足路径约束, max c_path=%g', max(c_path));

    %% 测试7: 终端拦截约束结构正确 (最后一项, 该直线未瞄准目标, 应为正)
    c_term = c(end);
    p_N = Z(9*N + 1 : 9*N + 3);
    p_tgt = target_model(Tf, target_init, target_vel);
    expected_term = (p_N - p_tgt)' * (p_N - p_tgt) - p.d_capture^2;
    assert(abs(c_term - expected_term) < 1e-6, '终端拦截约束计算不一致');

    fprintf('test_ocp_cost_constraints PASSED (J=%g, ceq_dim=%d, c_dim=%d, max_defect=%g)\n', ...
        J, numel(ceq), numel(c), max(abs(defects)));
end
