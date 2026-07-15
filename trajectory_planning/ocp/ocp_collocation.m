function [defects, Jdef] = ocp_collocation(Z, params)
%OCP_COLLOCATION Hermite-Simpson 配点离散化缺陷 (含可选解析雅可比)
%   defects = ocp_collocation(Z, params)                          -> 仅缺陷
%   [defects, Jdef] = ocp_collocation(Z, params)                  -> 缺陷 + 雅可比
%
% 输入:
%   Z      - 决策变量向量 [x0(6); u0(3); ...; xN(6); uN(3); Tf]
%            每个节点占用 9 个元素 (6 状态 + 3 控制), 共 N+1 个节点, 末尾 1 个 Tf
%            总长度 = 9*(N+1) + 1
%   params - 配置参数结构体 (使用 params.N)
%
% 输出:
%   defects - 配点缺陷向量 (6*N x 1)
%   Jdef    - (可选) 缺陷对 Z 的雅可比 (6N x nZ), 仅当 nargout>=2 时计算
%
% 对每段 i in [1,N]:
%   f_{i-1} = dynamics_model(x_{i-1}, u_{i-1}, params)
%   f_i     = dynamics_model(x_i, u_i, params)
%   h       = Tf / N
%   Hermite 中点: x_m = (x_{i-1} + x_i)/2 + h/8 * (f_{i-1} - f_i)
%   u_m = (u_{i-1} + u_i) / 2
%   f_m = dynamics_model(x_m, u_m, params)
%   Simpson 缺陷: x_i - x_{i-1} - h/6 * (f_{i-1} + 4*f_m + f_i)

    N  = params.N;
    Tf = Z(end);
    h  = Tf / N;                       % 每段时间步长
    nZ = numel(Z);

    defects = zeros(6*N, 1);
    need_jac = (nargout >= 2);
    if need_jac
        Jdef = zeros(6*N, nZ);
        I6 = eye(6);
    end

    for i = 1:N
        % 节点偏移 (0-based): 节点 k 的状态 x_k 起始于 9*k + 1
        off_prev = 9 * (i - 1);
        off_curr = 9 * i;

        x_prev = Z(off_prev + 1 : off_prev + 6);
        u_prev = Z(off_prev + 7 : off_prev + 9);
        x_curr = Z(off_curr + 1 : off_curr + 6);
        u_curr = Z(off_curr + 7 : off_curr + 9);

        % 两端节点动力学
        f_prev = dynamics_model(x_prev, u_prev, params);
        f_curr = dynamics_model(x_curr, u_curr, params);

        % Hermite 中点状态与中点控制
        x_mid = (x_prev + x_curr) / 2 + (h/8) * (f_prev - f_curr);
        u_mid = (u_prev + u_curr) / 2;
        f_mid = dynamics_model(x_mid, u_mid, params);

        rows = (i-1)*6 + (1:6);

        % Simpson 缺陷
        defects(rows) = x_curr - x_prev - (h/6) * (f_prev + 4*f_mid + f_curr);

        if need_jac
            % 解析雅可比 (链式法则)
            [A_prev, B_prev] = jacobian_dynamics(x_prev, u_prev, params);
            [A_curr, B_curr] = jacobian_dynamics(x_curr, u_curr, params);
            [A_mid,  B_mid]  = jacobian_dynamics(x_mid,  u_mid,  params);

            % x_m 对各变量的偏导
            dxm_dxprev = 0.5*I6 + (h/8)*A_prev;
            dxm_dxcurr = 0.5*I6 - (h/8)*A_curr;
            dxm_duprev = (h/8)*B_prev;
            dxm_ducurr = -(h/8)*B_curr;

            % f_m 对各变量的偏导 (f_m = f(x_m, u_m))
            dfm_dxprev = A_mid * dxm_dxprev;
            dfm_dxcurr = A_mid * dxm_dxcurr;
            dfm_duprev = A_mid * dxm_duprev + 0.5*B_mid;
            dfm_ducurr = A_mid * dxm_ducurr + 0.5*B_mid;

            % 缺陷对各变量的偏导
            % d_i = x_curr - x_prev - (h/6)*(f_prev + 4*f_m + f_curr)
            Jdef(rows, off_prev+1:off_prev+6) = -I6 - (h/6)*(A_prev + 4*dfm_dxprev);
            Jdef(rows, off_curr+1:off_curr+6) =  I6 - (h/6)*(A_curr + 4*dfm_dxcurr);
            Jdef(rows, off_prev+7:off_prev+9) = -(h/6)*(B_prev + 4*dfm_duprev);
            Jdef(rows, off_curr+7:off_curr+9) = -(h/6)*(B_curr + 4*dfm_ducurr);

            % 对 h 的偏导, 再乘 dh/dTf = 1/N 得到对 Tf 的偏导
            dfm_dh = A_mid * ((1/8)*(f_prev - f_curr));
            dd_dh  = -(1/6)*(f_prev + 4*f_mid + f_curr) - (h/6)*(4*dfm_dh);
            Jdef(rows, nZ) = dd_dh / N;
        end
    end
end
