function [u_opt, info] = mpc_controller(x_current, x_ref_window, u_ref_window, cfg)
    % LTV-MPC控制器 (QP形式, quadprog求解)
    % 将MPC转化为标准QP: min 0.5*u'Hu + f'u, s.t. lb<=u<=ub

    N = cfg.mpc.N;
    n = 6; m = 3;
    Q = cfg.mpc.Q; R = cfg.mpc.R;

    % 1. 逐点线性化
    A_seq = zeros(n, n, N);
    B_seq = zeros(n, m, N);
    for k = 1:N
        [A_seq(:,:,k), B_seq(:,:,k)] = ltv_linearize(x_ref_window(:,k), u_ref_window(:,k), cfg.aircraft, cfg.mpc.dt);
    end

    % 2. 终端权重P (DARE)
    A_avg = mean(A_seq, 3);
    B_avg = mean(B_seq, 3);
    P = dare(A_avg, B_avg, Q, R);

    % 3. 构建状态传播矩阵
    % x_vec = S_x * x_current + S_u * u_vec + S_offset
    S_x = zeros(n*N, n);
    S_u = sparse(n*N, m*N);
    S_offset = zeros(n*N, 1);

    % k=1: x(1) = x_current
    S_x(1:n, :) = eye(n);

    for k = 2:N
        row = (k-1)*n + 1:k*n;
        prev = (k-2)*n + 1:(k-1)*n;
        u_col = (k-2)*m + 1:(k-1)*m;

        offset_k = x_ref_window(:,k) - A_seq(:,:,k-1)*x_ref_window(:,k-1) - B_seq(:,:,k-1)*u_ref_window(:,k-1);

        S_x(row, :) = A_seq(:,:,k-1) * S_x(prev, :);
        S_u(row, :) = A_seq(:,:,k-1) * S_u(prev, :);
        S_u(row, u_col) = S_u(row, u_col) + B_seq(:,:,k-1);
        S_offset(row) = A_seq(:,:,k-1) * S_offset(prev) + offset_k;
    end

    % 4. 构建QP矩阵
    % Q_bar = blkdiag(Q,...,Q, Q+P), R_bar = blkdiag(R,...,R)
    Q_bar = kron(eye(N), Q);
    Q_bar((N-1)*n+1:N*n, (N-1)*n+1:N*n) = Q + P;
    R_bar = kron(eye(N), R);

    x_ref_vec = reshape(x_ref_window, n*N, 1);
    u_ref_vec = reshape(u_ref_window, m*N, 1);

    % d = S_x*x_current + S_offset - x_ref_vec
    d = S_x * x_current + S_offset - x_ref_vec;

    % J = (S_u*u + d)' Q_bar (S_u*u + d) + (u - u_ref)' R_bar (u - u_ref)
    % H = 2*(S_u' Q_bar S_u + R_bar), f = 2*(S_u' Q_bar d - R_bar u_ref)
    H = 2 * (S_u' * Q_bar * S_u + R_bar);
    f = 2 * (S_u' * Q_bar * d - R_bar * u_ref_vec);

    % 确保H正定 (数值稳定性)
    H = (H + H') / 2;
    min_eig = min(eig(H));
    if min_eig < 1e-8
        H = H + (1e-8 - min_eig) * eye(m*N);
    end

    % 5. 约束
    lb = repmat([cfg.constraints.T_min; -cfg.constraints.chi_dot_max; -cfg.constraints.gamma_dot_max], N, 1);
    ub = repmat([cfg.constraints.T_max; cfg.constraints.chi_dot_max; cfg.constraints.gamma_dot_max], N, 1);

    % 6. 求解QP
    options = optimoptions('quadprog', 'Display', 'off', 'Algorithm', 'interior-point-convex');
    tic;
    [u_seq_opt, ~, exitflag, output] = quadprog(H, f, [], [], [], [], lb, ub, u_ref_vec, options);
    solve_time = toc;

    u_opt = u_seq_opt(1:m);
    info.solve_time = solve_time;
    info.exitflag = exitflag;
    info.func_evals = output.iterations;
end
