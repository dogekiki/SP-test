function test_collocation
%TEST_COLLOCATION 测试 Hermite-Simpson 配点离散化 ocp_collocation.m
%   验证: 输出维度 6N x 1; 匀速直线轨迹缺陷接近 0; 任意轨迹缺陷非零

    p = params();
    N = p.N;

    %% 测试1: 输出维度检查 (6N x 1)
    V = 50; chi = 0; gamma = 0;
    Tf = 100;
    Z = build_straight_Z(N, [0;0;1000;V;chi;gamma], [0;0;0], Tf, V, chi, gamma);
    defects = ocp_collocation(Z, p);
    assert(isequal(size(defects), [6*N, 1]), ...
        'defects 维度应为 6N x 1');

    %% 测试2: 匀速直线轨迹 (chi=0, gamma=0) 缺陷接近 0
    assert(max(abs(defects)) < 1e-8, ...
        '匀速直线轨迹缺陷应接近 0 (<1e-8), 实际 max=%g', max(abs(defects)));

    %% 测试3: 倾斜爬升匀速直线 (chi=0.3, gamma=0.2, V=60) 缺陷接近 0
    V3 = 60; chi3 = 0.3; gamma3 = 0.2;
    x0_3 = [0; 0; 800; V3; chi3; gamma3];
    Z3 = build_straight_Z(N, x0_3, [0;0;0], 80, V3, chi3, gamma3);
    defects3 = ocp_collocation(Z3, p);
    assert(isequal(size(defects3), [6*N, 1]), '倾斜轨迹缺陷维度错误');
    assert(max(abs(defects3)) < 1e-8, ...
        '倾斜匀速直线轨迹缺陷应接近 0, 实际 max=%g', max(abs(defects3)));

    %% 测试4: 不满足动力学的轨迹 -> 缺陷非零 (验证函数确实在计算)
    Z_bad = Z;
    Z_bad(10:15) = Z_bad(10:15) + 100;   % 扰动 x1, 破坏匀速直线
    defects_bad = ocp_collocation(Z_bad, p);
    assert(max(abs(defects_bad)) > 1, ...
        '扰动后轨迹缺陷应明显非零');

    %% 测试5: 总长度自洽性 (9*(N+1)+1)
    assert(numel(Z) == 9*(N+1) + 1, 'Z 总长度自洽性检查失败');

    fprintf('test_collocation PASSED (max defect = %g)\n', max(abs(defects)));
end

%% 辅助函数: 构造匀速直线轨迹的决策向量 Z
function Z = build_straight_Z(N, x0, u0, Tf, V, chi, gamma)
%   匀速直线: x_k = x0 + f * (Tf/N) * k, 其中 f = dynamics_model 常值导数
    h = Tf / N;
    f = [V*cos(gamma)*cos(chi); V*cos(gamma)*sin(chi); V*sin(gamma); 0; 0; 0];
    Z = zeros(9*(N+1) + 1, 1);
    for k = 0:N
        xk = x0 + f * (h * k);
        Z(9*k + 1 : 9*k + 6) = xk;
        Z(9*k + 7 : 9*k + 9) = u0;
    end
    Z(end) = Tf;
end
