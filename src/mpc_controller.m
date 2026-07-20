function [u_opt, info] = mpc_controller(x_current, x_ref_window, u_ref_window, cfg)
    % LTV-MPC控制器
    N = cfg.mpc.N;
    n = 6; m = 3;
    Q = cfg.mpc.Q; R = cfg.mpc.R;
    
    % 1. 逐点线性化
    A_seq = zeros(n, n, N);
    B_seq = zeros(n, m, N);
    for k = 1:N
        [A_seq(:,:,k), B_seq(:,:,k)] = ltv_linearize(x_ref_window(:,k), u_ref_window(:,k), cfg.aircraft, cfg.mpc.dt);
    end
    
    % 2. 终端权重P (DARE近似)
    A_avg = mean(A_seq, 3);
    B_avg = mean(B_seq, 3);
    P = dare(A_avg, B_avg, Q, R);
    
    % 3. 决策变量
    u0 = reshape(u_ref_window, N*m, 1);
    
    % 4. 目标函数
    cost_fn = @(u_seq) mpc_cost(u_seq, x_current, x_ref_window, u_ref_window, A_seq, B_seq, Q, R, P, N, n, m);
    
    % 5. 约束
    lb = repmat([cfg.constraints.T_min; -cfg.constraints.chi_dot_max; -cfg.constraints.gamma_dot_max], N, 1);
    ub = repmat([cfg.constraints.T_max; cfg.constraints.chi_dot_max; cfg.constraints.gamma_dot_max], N, 1);
    
    % 6. fmincon求解
    options = optimoptions('fmincon', 'Display', 'off', 'Algorithm', 'sqp', 'MaxFunctionEvaluations', 2000);
    tic;
    [u_seq_opt, ~, exitflag, output] = fmincon(cost_fn, u0, [], [], [], [], lb, ub, [], options);
    solve_time = toc;
    
    u_opt = u_seq_opt(1:m);
    info.solve_time = solve_time;
    info.exitflag = exitflag;
    info.func_evals = output.funcCount;
end

function cost = mpc_cost(u_seq, x_current, x_ref_window, u_ref_window, A_seq, B_seq, Q, R, P, N, n, m)
    u_mat = reshape(u_seq, m, N);
    x = x_current;
    cost = 0;
    for k = 1:N
        x_tilde = x - x_ref_window(:,k);
        u_tilde = u_mat(:,k) - u_ref_window(:,k);
        cost = cost + x_tilde' * Q * x_tilde + u_tilde' * R * u_tilde;
        x = A_seq(:,:,k) * x + B_seq(:,:,k) * u_mat(:,k) + (x_ref_window(:,k) - A_seq(:,:,k) * x_ref_window(:,k) - B_seq(:,:,k) * u_ref_window(:,k));
    end
    x_tilde_N = x - x_ref_window(:,N);
    cost = cost + x_tilde_N' * P * x_tilde_N;
end
