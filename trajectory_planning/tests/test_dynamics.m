function test_dynamics
%TEST_DYNAMICS 测试飞行器动力学模型 dynamics_model.m
%   验证水平匀速直线、45度航向、爬升飞行及输出维度

    p = params();
    tol = 1e-10;

    %% 测试1: 水平匀速直线飞行
    %  chi=0, gamma=0, V=50, 控制全零 -> dx=[50,0,0,0,0,0]
    x = [0; 0; 0; 50; 0; 0];
    u = [0; 0; 0];
    dxdt = dynamics_model(x, u, p);
    assert(isequal(size(dxdt), [6,1]), 'dxdt should be 6x1');
    assert(abs(dxdt(1) - 50) < tol, 'dx should be V=50');
    assert(abs(dxdt(2) - 0) < tol, 'dy should be 0');
    assert(abs(dxdt(3) - 0) < tol, 'dz should be 0');
    assert(abs(dxdt(4) - 0) < tol, 'dV should be 0');
    assert(abs(dxdt(5) - 0) < tol, 'dchi should be 0');
    assert(abs(dxdt(6) - 0) < tol, 'dgamma should be 0');

    %% 测试2: 45度航向飞行
    %  chi=pi/4, gamma=0, V=50 -> dx=V*cos(pi/4), dy=V*sin(pi/4)
    chi = pi/4;
    x = [0; 0; 0; 50; chi; 0];
    u = [0; 0; 0];
    dxdt = dynamics_model(x, u, p);
    assert(abs(dxdt(1) - 50*cos(chi)) < tol, 'dx mismatch at 45deg');
    assert(abs(dxdt(2) - 50*sin(chi)) < tol, 'dy mismatch at 45deg');
    assert(abs(dxdt(3) - 0) < tol, 'dz should be 0 (level)');

    %% 测试3: 爬升飞行
    %  gamma=pi/6, V=60 -> dz=V*sin(gamma), dx=V*cos(gamma)*cos(chi)
    gamma = pi/6;
    V = 60;
    chi = 0;
    x = [0; 0; 0; V; chi; gamma];
    u = [0; 0; 0];
    dxdt = dynamics_model(x, u, p);
    assert(abs(dxdt(1) - V*cos(gamma)*cos(chi)) < tol, 'dx mismatch in climb');
    assert(abs(dxdt(2) - V*cos(gamma)*sin(chi)) < tol, 'dy mismatch in climb');
    assert(abs(dxdt(3) - V*sin(gamma)) < tol, 'dz mismatch in climb');

    %% 测试4: 控制输入作用
    %  u=[0.1,0.05,2] -> dchi=0.1, dgamma=0.05, dV=2
    x = [0; 0; 0; 50; 0; 0];
    u = [0.1; 0.05; 2];
    dxdt = dynamics_model(x, u, p);
    assert(abs(dxdt(4) - 2) < tol, 'dV should be u(3)=2');
    assert(abs(dxdt(5) - 0.1) < tol, 'dchi should be u(1)=0.1');
    assert(abs(dxdt(6) - 0.05) < tol, 'dgamma should be u(2)=0.05');

    %% 测试5: 输出维度
    x = [100; 200; 300; 50; 0.5; -0.1];
    u = [0.05; 0.02; -1];
    dxdt = dynamics_model(x, u, p);
    assert(isequal(size(dxdt), [6,1]), 'dxdt must be 6x1 column vector');
    assert(isfinite(norm(dxdt)), 'dxdt must be finite');

    fprintf('test_dynamics PASSED\n');
end
