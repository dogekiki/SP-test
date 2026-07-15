function test_jacobian
%TEST_JACOBIAN 测试解析雅可比矩阵 jacobian_dynamics.m
%   与数值雅可比（中心差分）对比，并验证 B 的结构

    p = params();
    tol = 1e-6;       % 解析与数值雅可比允许误差
    h = 1e-6;         % 中心差分步长

    % 一般飞行状态与控制
    x = [100; -50; 300; 55; 0.4; 0.1];
    u = [0.05; 0.02; -1];

    [A, B] = jacobian_dynamics(x, u, p);

    %% 维度检查
    assert(isequal(size(A), [6,6]), 'A must be 6x6');
    assert(isequal(size(B), [6,3]), 'B must be 6x3');

    %% 数值雅可比 A (对状态中心差分)
    A_num = zeros(6,6);
    for i = 1:6
        xp = x;  xp(i) = xp(i) + h;
        xm = x;  xm(i) = xm(i) - h;
        fp = dynamics_model(xp, u, p);
        fm = dynamics_model(xm, u, p);
        A_num(:,i) = (fp - fm) / (2*h);
    end
    errA = max(abs(A(:) - A_num(:)));
    assert(errA < tol, sprintf('A 与数值雅可比误差过大: %g', errA));

    %% 数值雅可比 B (对控制中心差分)
    B_num = zeros(6,3);
    for j = 1:3
        up = u;  up(j) = up(j) + h;
        um = u;  um(j) = um(j) - h;
        fp = dynamics_model(x, up, p);
        fm = dynamics_model(x, um, p);
        B_num(:,j) = (fp - fm) / (2*h);
    end
    errB = max(abs(B(:) - B_num(:)));
    assert(errB < tol, sprintf('B 与数值雅可比误差过大: %g', errB));

    %% 验证 B 的结构
    B_expected = zeros(6,3);
    B_expected(4,3) = 1;   % dV/dV_dot
    B_expected(5,1) = 1;   % dchi/dchi_dot
    B_expected(6,2) = 1;   % dgamma/dgamma_dot
    assert(max(abs(B(:) - B_expected(:))) < tol, 'B 结构与预期不符');

    %% 多组状态验证 A
    test_states = {
        [0;0;0;30;0;0], ...
        [0;0;0;80;pi/4;pi/6], ...
        [10;20;100;50;-0.5;0.35], ...
        [-5;8;0;45;0;0]
    };
    for k = 1:length(test_states)
        xk = test_states{k};
        [Ak, ~] = jacobian_dynamics(xk, u, p);
        Ak_num = zeros(6,6);
        for i = 1:6
            xp = xk;  xp(i) = xp(i) + h;
            xm = xk;  xm(i) = xm(i) - h;
            Ak_num(:,i) = (dynamics_model(xp,u,p) - dynamics_model(xm,u,p))/(2*h);
        end
        err = max(abs(Ak(:) - Ak_num(:)));
        assert(err < tol, sprintf('状态 %d 处 A 误差过大: %g', k, err));
    end

    fprintf('test_jacobian PASSED\n');
end
