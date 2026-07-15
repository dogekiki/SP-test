function test_target_model
%TEST_TARGET_MODEL 测试目标运动模型 target_model.m
%   验证 t=0、t=10、反向外推及输出维度

    tol = 1e-10;

    target_init = [100; 200; 50];
    target_vel  = [10; -5; 2];

    %% 测试1: t=0 返回初始位置
    pos0 = target_model(0, target_init, target_vel);
    assert(isequal(size(pos0), [3,1]), 'pos must be 3x1');
    assert(max(abs(pos0 - target_init)) < tol, 't=0 should return init');

    %% 测试2: t=10 返回 init + vel*10
    pos10 = target_model(10, target_init, target_vel);
    expected = target_init + target_vel * 10;
    assert(max(abs(pos10 - expected)) < tol, 't=10 mismatch');

    %% 测试3: 反向外推 (负时间)
    pos_neg = target_model(-5, target_init, target_vel);
    expected_neg = target_init + target_vel * (-5);
    assert(max(abs(pos_neg - expected_neg)) < tol, 'negative t mismatch');

    %% 测试4: 维度检查 (3x1)
    pos = target_model(3.7, target_init, target_vel);
    assert(isequal(size(pos), [3,1]), 'output must be 3x1 column vector');
    assert(isfinite(norm(pos)), 'output must be finite');

    %% 测试5: 零速度时位置恒定
    pos_static = target_model(100, target_init, [0;0;0]);
    assert(max(abs(pos_static - target_init)) < tol, ...
        'zero velocity should keep position constant');

    fprintf('test_target_model PASSED\n');
end
