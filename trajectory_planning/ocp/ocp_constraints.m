function [c, ceq, gradc, gradceq] = ocp_constraints(Z, x0, u0, target_init, target_vel, params)
%OCP_CONSTRAINTS OCP 非线性约束函数 (含可选解析雅可比)
%   [c, ceq] = ocp_constraints(...)                       -> 仅约束
%   [c, ceq, gradc, gradceq] = ocp_constraints(...)        -> 约束 + 雅可比
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
%   c   - 不等式约束 (要求 <= 0), 维度 (6*(N+1) + 1) x 1:
%         每个配点 k=0..N:
%           V_min - V <= 0 ; V - V_max <= 0 ; |gamma| - gamma_max <= 0
%           |chi_dot| - chi_dot_max ; |gamma_dot| - gamma_dot_max ; |V_dot| - V_dot_max
%         终端拦截: ||p_N - p_target(Tf)||^2 - d_capture^2 <= 0
%   gradc, gradceq - (可选) 约束对 Z 的雅可比, 仅当 nargout>=3 时计算

    N  = params.N;
    Tf = Z(end);
    nZ = numel(Z);
    need_jac = (nargout >= 3);

    %% ===== 等式约束 ceq =====
    if need_jac
        [defects, Jdef] = ocp_collocation(Z, params);   % 6N x 1, 6N x nZ
    else
        defects = ocp_collocation(Z, params);           % 6N x 1
    end
    init_x = Z(1:6) - x0;                               % 6 x 1
    init_u = Z(7:9) - u0;                               % 3 x 1
    ceq = [defects; init_x; init_u];                    % (6N + 9) x 1

    %% ===== 不等式约束 c (<= 0) =====
    nc = 6*(N+1) + 1;
    c = zeros(nc, 1);
    if need_jac
        gradc = zeros(nc, nZ);
    end

    for k = 0:N
        off = 9 * k;
        xk  = Z(off + 1 : off + 6);
        uk  = Z(off + 7 : off + 9);

        V     = xk(4);
        gamma = xk(6);

        row = 6*k + 1;
        c(row)     = params.V_min - V;                   % V_min - V <= 0
        c(row + 1) = V - params.V_max;                   % V - V_max <= 0
        c(row + 2) = abs(gamma) - params.gamma_max;      % |gamma| - gamma_max
        c(row + 3) = abs(uk(1)) - params.chi_dot_max;    % |chi_dot|
        c(row + 4) = abs(uk(2)) - params.gamma_dot_max;  % |gamma_dot|
        c(row + 5) = abs(uk(3)) - params.V_dot_max;      % |V_dot|

        if need_jac
            % |.| 在 0 处取次梯度 0
            sg_gamma = sign(gamma);     if sg_gamma==0, sg_gamma=0; end
            sg_cdot  = sign(uk(1));     if sg_cdot==0,  sg_cdot=0;  end
            sg_gdot  = sign(uk(2));     if sg_gdot==0,  sg_gdot=0;  end
            sg_vdot  = sign(uk(3));     if sg_vdot==0,  sg_vdot=0;  end
            gradc(row,     off+4) = -1;          % d(V_min-V)/dV
            gradc(row + 1, off+4) =  1;          % d(V-V_max)/dV
            gradc(row + 2, off+6) = sg_gamma;    % d|gamma|/dgamma
            gradc(row + 3, off+7) = sg_cdot;     % d|chi_dot|/dchi_dot
            gradc(row + 4, off+8) = sg_gdot;     % d|gamma_dot|/dgamma_dot
            gradc(row + 5, off+9) = sg_vdot;     % d|V_dot|/dV_dot
        end
    end

    % 终端拦截约束
    off_N  = 9 * N;
    p_N    = Z(off_N + 1 : off_N + 3);                  % 终端位置 [x;y;z]
    p_tgt  = target_model(Tf, target_init, target_vel);
    diff_p = p_N - p_tgt;
    c(end) = diff_p' * diff_p - params.d_capture^2;

    if need_jac
        % 对 p_N (off_N+1:off_N+3) 的偏导: 2*diff_p'
        gradc(end, off_N+1:off_N+3) = 2 * diff_p';
        % 对 Tf 的偏导: d/dTf[ ||p_N - p_tgt(Tf)||^2 ] = 2*diff_p' * (-target_vel)
        gradc(end, nZ) = -2 * (diff_p' * target_vel);
    end

    %% ===== 等式约束雅可比 gradceq =====
    if need_jac
        gradceq = zeros(6*N + 9, nZ);
        gradceq(1:6*N, :) = Jdef;
        % 初始状态约束 Z(1:6)-x0: 雅可比为 I6 在列 1:6
        gradceq(6*N+1 : 6*N+6, 1:6) = eye(6);
        % 初始控制约束 Z(7:9)-u0: 雅可比为 I3 在列 7:9
        gradceq(6*N+7 : 6*N+9, 7:9) = eye(3);
    end

    %% ===== fmincon 约定: 梯度为 nvars x ncons, 需转置 =====
    if need_jac
        gradc   = gradc.';
        gradceq = gradceq.';
    end
end
