function test_params
%TEST_PARAMS 测试配置参数模块 params.m
%   验证所有物理约束、OCP、MPC、权重矩阵和求解器选项参数正确

    p = params();

    %% 物理约束
    assert(p.V_min == 30, 'V_min should be 30');
    assert(p.V_max == 80, 'V_max should be 80');
    assert(p.chi_dot_max == 0.15, 'chi_dot_max should be 0.15');
    assert(p.gamma_max == 0.35, 'gamma_max should be 0.35');
    assert(p.gamma_dot_max == 0.10, 'gamma_dot_max should be 0.10');
    assert(p.V_dot_max == 5, 'V_dot_max should be 5');
    assert(p.z_min == 0, 'z_min should be 0');

    %% 最小转弯半径
    assert(abs(p.R_min - p.V_min / p.chi_dot_max) < 1e-12, ...
        'R_min should equal V_min / chi_dot_max');

    %% 捕获距离
    assert(p.d_capture == 100, 'd_capture should be 100');

    %% OCP 参数
    assert(p.N == 40, 'N should be 40');
    assert(p.w_smooth == 0.01, 'w_smooth should be 0.01');

    %% MPC 参数
    assert(p.Np == 10, 'Np should be 10');
    assert(p.Nc == 5, 'Nc should be 5');
    assert(p.dt_mpc == 0.1, 'dt_mpc should be 0.1');
    assert(p.replan_threshold == 0.8, 'replan_threshold should be 0.8');
    assert(abs(p.replan_min_interval - 2*p.Np*p.dt_mpc) < 1e-12, ...
        'replan_min_interval should be 2*Np*dt_mpc');

    %% 权重矩阵
    assert(isequal(size(p.Q), [6,6]), 'Q should be 6x6');
    assert(isequal(diag(p.Q), [10;10;10;1;1;1]), 'Q diagonal mismatch');
    assert(isequal(size(p.R), [3,3]), 'R should be 3x3');
    assert(isequal(diag(p.R), [0.1;0.1;0.1]), 'R diagonal mismatch');
    assert(isempty(p.P), 'P should be empty');

    %% fmincon 选项
    assert(strcmpi(p.fmincon_opts.Algorithm, 'sqp'), 'fmincon Algorithm should be sqp');
    assert(p.fmincon_opts.MaxFunctionEvaluations == 1e4, ...
        'MaxFunctionEvaluations should be 1e4');
    assert(p.fmincon_opts.StepTolerance == 1e-8, 'StepTolerance should be 1e-8');
    assert(p.fmincon_opts.ConstraintTolerance == 1e-6, ...
        'ConstraintTolerance should be 1e-6');
    assert(strcmpi(p.fmincon_opts.Display, 'iter'), 'fmincon Display should be iter');

    %% QP 选项
    assert(strcmpi(p.qp_opts.Display, 'off'), 'qp Display should be off');
    assert(p.qp_opts.OptimalityTolerance == 1e-8, ...
        'qp OptimalityTolerance should be 1e-8');

    fprintf('test_params PASSED\n');
end
