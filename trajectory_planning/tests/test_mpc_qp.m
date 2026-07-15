function test_mpc_qp
%TEST_MPC_QP 测试 MPC 线性化与 QP 构建
%   验证:
%     1. mpc_linearize: Phi = I + A*dt, Gamma = B*dt, 维度正确
%     2. mpc_build_qp: H 对称且正定, g/H 维度正确, 约束矩阵结构正确

    p = params();

    %% 参考状态与控制
    x_ref = [100; 200; 500; 50; 0.3; 0.1];
    u_ref = [0.05; 0.02; 1.0];

    %% ========== 测试 mpc_linearize ==========
    [Phi, Gamma] = mpc_linearize(x_ref, u_ref, p);

    % 与 jacobian_dynamics 对比
    [A, B] = jacobian_dynamics(x_ref, u_ref, p);
    dt = p.dt_mpc;

    % 验证 Phi = I + A*dt
    Phi_expected = eye(6) + A * dt;
    errPhi = max(abs(Phi(:) - Phi_expected(:)));
    assert(errPhi < 1e-12, sprintf('Phi 应为 I + A*dt, 误差=%g', errPhi));

    % 验证 Gamma = B*dt
    Gamma_expected = B * dt;
    errGamma = max(abs(Gamma(:) - Gamma_expected(:)));
    assert(errGamma < 1e-12, sprintf('Gamma 应为 B*dt, 误差=%g', errGamma));

    % 维度检查
    assert(isequal(size(Phi), [6, 6]), 'Phi 应为 6x6');
    assert(isequal(size(Gamma), [6, 3]), 'Gamma 应为 6x3');

    fprintf('  [mpc_linearize] Phi = I + A*dt  (误差=%g)\n', errPhi);
    fprintf('  [mpc_linearize] Gamma = B*dt    (误差=%g)\n', errGamma);

    %% ========== 测试 mpc_build_qp ==========
    dx0 = [5; -3; 2; 1; 0.02; -0.01];
    [H, g, A_con, lb_vec, ub_vec] = mpc_build_qp(Phi, Gamma, dx0, x_ref, u_ref, p);

    Nc = p.Nc;
    nu = 3;
    n_du = nu * Nc;              % 15
    n_rate = nu * (Nc - 1);      % 12

    %% H 维度: 3*Nc x 3*Nc
    assert(isequal(size(H), [n_du, n_du]), ...
        sprintf('H 维度应为 [%d,%d], 实际 [%d,%d]', n_du, n_du, size(H)));

    %% g 维度: 3*Nc x 1
    assert(isequal(size(g), [n_du, 1]), ...
        sprintf('g 维度应为 [%d,1], 实际 [%d,%d]', n_du, size(g)));

    %% H 对称
    sym_err = max(max(abs(H - H')));
    assert(sym_err < 1e-10, sprintf('H 应对称, 对称误差=%g', sym_err));

    %% H 正定 (min(eig) > 0)
    min_eig = min(real(eig(H)));
    assert(min_eig > 0, sprintf('H 应正定, min(eig)=%g', min_eig));

    fprintf('  [mpc_build_qp] H 维度 [%d,%d], 对称误差=%g, min(eig)=%.6f\n', ...
        size(H), sym_err, min_eig);

    %% A_con 维度: [n_du + n_rate, n_du]
    assert(isequal(size(A_con), [n_du + n_rate, n_du]), ...
        sprintf('A_con 维度应为 [%d,%d], 实际 [%d,%d]', n_du + n_rate, n_du, size(A_con)));

    %% lb_vec, ub_vec 维度
    assert(isequal(size(lb_vec, 1), n_du + n_rate), 'lb_vec 行数不匹配');
    assert(isequal(size(ub_vec, 1), n_du + n_rate), 'ub_vec 行数不匹配');

    %% A_con 上半部分为 eye(3*Nc)
    assert(max(max(abs(A_con(1:n_du, :) - eye(n_du)))) < 1e-12, 'A_con 上半部分应为 eye(3*Nc)');

    %% lb <= ub
    assert(all(lb_vec <= ub_vec + 1e-12), '所有约束 lb 应 <= ub');

    %% 验证约束逻辑: 控制范围
    u_min = [-p.chi_dot_max; -p.gamma_dot_max; -p.V_dot_max];
    u_max = [ p.chi_dot_max;  p.gamma_dot_max;  p.V_dot_max];
    du_lb_expected = u_min - u_ref;
    du_ub_expected = u_max - u_ref;
    for k = 1:Nc
        assert(max(abs(lb_vec((k-1)*nu+1:k*nu) - du_lb_expected)) < 1e-12, ...
            '控制范围 lb 不正确');
        assert(max(abs(ub_vec((k-1)*nu+1:k*nu) - du_ub_expected)) < 1e-12, ...
            '控制范围 ub 不正确');
    end

    %% 验证约束逻辑: 控制增量
    du_rate_max = [0.05; 0.05; 1.0];
    for k = 1:Nc-1
        assert(max(abs(lb_vec(n_du + (k-1)*nu+1 : n_du + k*nu) - (-du_rate_max))) < 1e-12, ...
            '增量约束 lb 不正确');
        assert(max(abs(ub_vec(n_du + (k-1)*nu+1 : n_du + k*nu) - du_rate_max)) < 1e-12, ...
            '增量约束 ub 不正确');
    end

    fprintf('  [mpc_build_qp] A_con [%d,%d], 约束结构验证通过\n', size(A_con));

    fprintf('test_mpc_qp PASSED\n');
end
