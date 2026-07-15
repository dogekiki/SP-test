function test_mpc_correct
%TEST_MPC_CORRECT 测试 MPC 修正主函数与重规划触发
%   验证:
%     1. mpc_replan_trigger: 三种触发场景
%     2. mpc_correct: 匀速直线基准轨迹下的修正控制输出

    p = params();

    %% ========== 测试 mpc_replan_trigger ==========
    Tf = 100;

    % 场景1: t=10, Tf=100 -> 10 < 0.8*100=80, 不触发
    flag1 = mpc_replan_trigger(10, Tf, 0, p);
    assert(flag1 == 0, sprintf('t=10, Tf=100 不应触发, 实际 flag=%d', flag1));

    % 场景2: t=85, Tf=100 -> 85 > 80 且 85-0 >= 2.0, 触发
    flag2 = mpc_replan_trigger(85, Tf, 0, p);
    assert(flag2 == 1, sprintf('t=85, Tf=100 应触发, 实际 flag=%d', flag2));

    % 场景3: t=86, last=85 -> 86 > 80 但 86-85=1 < 2.0, 不触发
    flag3 = mpc_replan_trigger(86, Tf, 85, p);
    assert(flag3 == 0, sprintf('t=86, last=85 不应触发 (间隔太近), 实际 flag=%d', flag3));

    fprintf('  [mpc_replan_trigger] 场景1 (t=10): flag=%d [PASS]\n', flag1);
    fprintf('  [mpc_replan_trigger] 场景2 (t=85): flag=%d [PASS]\n', flag2);
    fprintf('  [mpc_replan_trigger] 场景3 (t=86,last=85): flag=%d [PASS]\n', flag3);

    %% ========== 测试 mpc_correct ==========
    % 构造匀速直线基准轨迹: 沿 x 轴匀速飞行, V=50, chi=0, gamma=0
    N  = 40;
    Tf = 50;
    h  = Tf / N;       % 1.25 s
    V  = 50;

    traj_ref = zeros(6, N+1);
    ctrl_ref = zeros(3, N+1);
    for k = 0:N
        traj_ref(:, k+1) = [V * k * h; 0; 1000; V; 0; 0];
        ctrl_ref(:, k+1) = [0; 0; 0];
    end

    % 实际状态有偏差
    t_now = 2.0;
    idx_ref = max(1, min(floor(t_now / h) + 1, N + 1));
    x_ref = traj_ref(:, idx_ref);
    x_actual = x_ref + [10; -5; 3; 2; 0.05; 0.02];

    target_pos = [3000; 0; 1000];

    [u_corr, replan_flag] = mpc_correct(x_actual, t_now, traj_ref, ctrl_ref, Tf, target_pos, p);

    %% 验证 u_corr 是 3x1
    assert(isequal(size(u_corr), [3, 1]), ...
        sprintf('u_corr 应为 3x1, 实际 [%d,%d]', size(u_corr)));

    %% 验证 u_corr 在控制约束内
    u_min = [-p.chi_dot_max; -p.gamma_dot_max; -p.V_dot_max];
    u_max = [ p.chi_dot_max;  p.gamma_dot_max;  p.V_dot_max];
    assert(all(u_corr >= u_min - 1e-6) && all(u_corr <= u_max + 1e-6), ...
        sprintf('u_corr 应在控制约束内, 实际 u_corr=[%g;%g;%g], 约束[%g;%g;%g]~[%g;%g;%g]', ...
            u_corr(1), u_corr(2), u_corr(3), u_min(1), u_min(2), u_min(3), ...
            u_max(1), u_max(2), u_max(3)));

    %% 验证 replan_flag = 0 (t=2 < 0.8*50=40)
    assert(replan_flag == 0, ...
        sprintf('replan_flag 应为 0 (t=2 < 0.8*50=40), 实际=%d', replan_flag));

    fprintf('  [mpc_correct] t_now=%.1f, idx=%d, u_corr=[%.4f; %.4f; %.4f]\n', ...
        t_now, idx_ref, u_corr(1), u_corr(2), u_corr(3));
    fprintf('  [mpc_correct] u_corr 维度 [3,1], 约束满足, replan_flag=%d [PASS]\n', replan_flag);

    fprintf('test_mpc_correct PASSED\n');
end
