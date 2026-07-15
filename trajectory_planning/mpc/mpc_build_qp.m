function [H, g, A_con, lb_vec, ub_vec] = mpc_build_qp(Phi, Gamma, dx0, x_ref, u_ref, params)
%MPC_BUILD_QP 构建 MPC 二次规划 (QP) 问题
%   [H, g, A_con, lb_vec, ub_vec] = mpc_build_qp(Phi, Gamma, dx0, x_ref, u_ref, params)
%
%   预测模型 (前向欧拉离散线性化):
%     dx_{k+1} = Phi * dx_k + Gamma * du_k
%   其中 dx_k = x_k - x_ref 为状态偏差, du_k = u_k - u_ref 为控制偏差。
%
%   预测时域 Np, 控制时域 Nc (Nc <= Np), 控制时域之后 du_k = 0。
%
%   代价函数:
%     min  J = sum_{k=1}^{Np} dx_k' * Q * dx_k + sum_{k=0}^{Nc-1} du_k' * R * du_k
%   展开为 QP 形式:
%     min  0.5 * dU' * H * dU + g' * dU
%   其中 dU = [du_0; du_1; ...; du_{Nc-1}] (3*Nc x 1)
%
%   约束:
%     1. 控制量范围: u_min <= u_ref + du_k <= u_max  (k=0..Nc-1)
%     2. 控制增量约束: |du_{k+1} - du_k| <= du_rate_max  (k=0..Nc-2)
%
% 输入:
%   Phi    - 离散状态转移矩阵 (6x6)
%   Gamma  - 离散控制输入矩阵 (6x3)
%   dx0    - 当前状态偏差 x_actual - x_ref (6x1)
%   x_ref  - 参考状态 (6x1)  [本函数未直接使用, 保留接口]
%   u_ref  - 参考控制 (3x1)
%   params - 配置参数结构体
%
% 输出:
%   H      - QP 海森矩阵 (3*Nc x 3*Nc), 对称正定
%   g      - QP 线性项 (3*Nc x 1)
%   A_con  - 约束矩阵 [eye(3*Nc); rate_matrix], 满足 lb_vec <= A_con*dU <= ub_vec
%   lb_vec - 约束下界 (3*Nc + 3*(Nc-1)) x 1
%   ub_vec - 约束上界 (3*Nc + 3*(Nc-1)) x 1

    Np = params.Np;          % 预测时域
    Nc = params.Nc;          % 控制时域
    nx = 6;                  % 状态维数
    nu = 3;                  % 控制维数
    Q  = params.Q;           % 状态权重 (6x6)
    R  = params.R;           % 控制权重 (3x3)
    P  = params.P;           % 终端权重 (可为空)

    %% 1. 构建状态传播矩阵 Sx 和控制传播矩阵 Su
    %    dx_k = Phi^k * dx0 + sum_{j=0}^{min(k-1,Nc-1)} Phi^{k-1-j} * Gamma * du_j
    %
    %    Sx [nx*Np x nx]:  第 k 块 = Phi^k,  k = 1..Np
    %    Su [nx*Np x nu*Nc]: 第 (k,j) 块 = Phi^{k-1-j} * Gamma,  k=1..Np, j=0..Nc-1 (j<k)

    % 预计算 Phi 的幂: Phi_pow{m+1} = Phi^m, m = 0..Np
    Phi_pow = cell(Np + 1, 1);
    Phi_pow{1} = eye(nx);
    for m = 1:Np
        Phi_pow{m+1} = Phi_pow{m} * Phi;
    end

    Sx = zeros(nx * Np, nx);
    Su = zeros(nx * Np, nu * Nc);
    for k = 1:Np
        % Sx 第 k 块 = Phi^k
        Sx((k-1)*nx+1 : k*nx, :) = Phi_pow{k+1};
        % Su 第 (k, j) 块
        for j = 0:Nc-1
            if j < k
                % Phi^{k-1-j} * Gamma, 对应 Phi_pow 索引 (k-1-j)+1 = k-j
                Su((k-1)*nx+1 : k*nx, j*nu+1 : (j+1)*nu) = Phi_pow{k-j} * Gamma;
            end
        end
    end

    %% 2. 构建权重块矩阵
    %    Q_bar = kron(eye(Np), Q), 终端块用 P 代替 (P 为空时用 Q)
    %    R_bar = kron(eye(Nc), R)
    Q_bar = kron(eye(Np), Q);
    if ~isempty(P)
        Q_bar((Np-1)*nx+1 : Np*nx, (Np-1)*nx+1 : Np*nx) = P;
    end
    R_bar = kron(eye(Nc), R);

    %% 3. 构建 QP 代价矩阵
    %    J = (Sx*dx0 + Su*dU)' * Q_bar * (Sx*dx0 + Su*dU) + dU' * R_bar * dU
    %      = dU' * (Su'*Q_bar*Su + R_bar) * dU + 2 * (Sx*dx0)' * Q_bar * Su * dU + const
    %    => H = 2*(Su'*Q_bar*Su + R_bar),  g = 2*Su'*Q_bar*Sx*dx0
    H = 2 * (Su' * Q_bar * Su + R_bar);
    H = (H + H') / 2;          % 确保对称
    g = 2 * Su' * Q_bar * Sx * dx0;

    %% 4. 构建约束
    %    4a. 控制量范围约束: u_min <= u_ref + du_k <= u_max  =>  u_min - u_ref <= du_k <= u_max - u_ref
    u_min = [-params.chi_dot_max; -params.gamma_dot_max; -params.V_dot_max];
    u_max = [ params.chi_dot_max;  params.gamma_dot_max;  params.V_dot_max];

    du_lb = u_min - u_ref;     % 单步控制偏差下界 (3x1)
    du_ub = u_max - u_ref;     % 单步控制偏差上界 (3x1)

    % 4b. 控制增量约束: |du_{k+1} - du_k| <= du_rate_max
    du_rate_max = [0.05; 0.05; 1.0];

    % 约束矩阵 A_con = [eye(3*Nc); rate_matrix]
    n_du   = nu * Nc;                 % 决策变量维数
    n_rate = nu * (Nc - 1);           % 增量约束行数
    A_con  = [eye(n_du); zeros(n_rate, n_du)];

    % 填充 rate_matrix: du_{k+1} - du_k, k=0..Nc-2
    for k = 0:Nc-2
        row = k * nu + 1;             % 行起始 (1-indexed)
        col_k  = k * nu + 1;          % du_k 列起始
        col_k1 = (k+1) * nu + 1;      % du_{k+1} 列起始
        A_con(n_du + row : n_du + row + nu - 1, col_k  : col_k  + nu - 1) = -eye(nu);
        A_con(n_du + row : n_du + row + nu - 1, col_k1 : col_k1 + nu - 1) =  eye(nu);
    end

    % 约束上下界
    lb_vec = [repmat(du_lb, Nc, 1); repmat(-du_rate_max, Nc-1, 1)];
    ub_vec = [repmat(du_ub, Nc, 1); repmat( du_rate_max, Nc-1, 1)];
end
