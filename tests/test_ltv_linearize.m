function test_ltv_linearize
    cfg = config();
    x_ref = [0; 0; 100; 30; 0; 0];
    u_ref = [50; 0; 0];
    [A, B] = ltv_linearize(x_ref, u_ref, cfg.aircraft, cfg.mpc.dt);
    
    assert(isequal(size(A), [6,6]), 'A应为6x6');
    assert(isequal(size(B), [6,3]), 'B应为6x3');
    assert(all(abs(diag(A) - 1) < 0.5), 'A对角线应接近1');
    
    fprintf('test_ltv_linearize: PASS\n');
end
