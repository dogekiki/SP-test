function [c, ceq] = ocp_constraints(Z, x0, u0, target_init, target_vel, params)
%OCP_CONSTRAINTS OCP 非线性约束函数
%   [c, ceq] = ocp_constraints(Z, x0, u0, target_init, target_vel, params)
%
% 输入:
%   Z           - 决策变量向量 [x0(6); u0(3); ...; xN(6); uN(3); Tf]
%   x0          - 初始状态 (6x1), 用于等式约束
%   u0          - 初始控制 (3x1), 用于等式约束
%   target_init - 目标初始位置 (3x1)
%   target_vel  - 目标常速度 (3x1)
%   params      - 配置参数结构体
%
% 输出:
%   ceq - 等式约束 (要求 = 0), 维度 (6N + 9) x 1:
%         [ 配点缺陷 (6N x 1);
%           初始状态约束 Z(1:6) - x0 (6 x 1);
%           初始控制约束 Z(7:9) - u0 (3 x 1) ]
%         (注: 6N + 6 + 3 = 6N + 9)
%   c   - 不等式约束 (要求 <= 0), 维度 (6*(N+1) + 1) x 1:
%         每个配点 k=0..N:
%           V_min - V <= 0
%           V - V_max <= 0
%           |gamma| - gamma_max <= 0
%           |chi_dot| - chi_dot_max <= 0
%           |gamma_dot| - gamma_dot_max <= 0
%           |V_dot| - V_dot_max <= 0
%         终端拦截: ||p_N - p_target(Tf)||^2 - d_capture^2 <= 0

    N  = params.N;
    Tf = Z(end);

    %% ===== 等式约束 ceq =====
    defects   = ocp_collocation(Z, params);   % 6N x 1
    init_x    = Z(1:6) - x0;                  % 6 x 1
    init_u    = Z(7:9) - u0;                  % 3 x 1
    ceq = [defects; init_x; init_u];          % (6N + 9) x 1

    %% ===== 不等式约束 c (<= 0) =====
    % 每个节点 6 个约束, 共 N+1 个节点, 加 1 个终端拦截
    c = zeros(6*(N+1) + 1, 1);

    for k = 0:N
        off = 9 * k;
        xk  = Z(off + 1 : off + 6);
        uk  = Z(off + 7 : off + 9);

        V     = xk(4);
        gamma = xk(6);

        row = 6*k + 1;
        c(row)     = params.V_min - V;                 % V_min - V <= 0
        c(row + 1) = V - params.V_max;                 % V - V_max <= 0
        c(row + 2) = abs(gamma) - params.gamma_max;    % |gamma| - gamma_max <= 0
        c(row + 3) = abs(uk(1)) - params.chi_dot_max;  % |chi_dot| - chi_dot_max
        c(row + 4) = abs(uk(2)) - params.gamma_dot_max;% |gamma_dot| - gamma_dot_max
        c(row + 5) = abs(uk(3)) - params.V_dot_max;    % |V_dot| - V_dot_max
    end

    % 终端拦截约束
    off_N   = 9 * N;
    p_N     = Z(off_N + 1 : off_N + 3);                % 终端位置 [x;y;z]
    p_tgt   = target_model(Tf, target_init, target_vel);
    c(end)  = (p_N - p_tgt)' * (p_N - p_tgt) - params.d_capture^2;
end
