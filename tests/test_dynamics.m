function test_dynamics
    cfg = config();
    % 测试1: 匀速平飞状态 (V=30, gamma=0, chi=0)
    x = [0; 0; 100; 30; 0; 0];
    u = [0; 0; 0];
    dxdt = dynamics_3dof(x, u, cfg.aircraft);
    assert(dxdt(1) > 0, 'px应增大');
    assert(abs(dxdt(2)) < 1e-10, 'py应不变');
    assert(abs(dxdt(3)) < 1e-10, 'pz应不变');
    
    % 测试2: 爬升状态
    x2 = [0; 0; 100; 30; 0; deg2rad(10)];
    dxdt2 = dynamics_3dof(x2, u, cfg.aircraft);
    assert(dxdt2(3) > 0, 'pz应增大(爬升)');
    
    fprintf('test_dynamics: PASS\n');
end
