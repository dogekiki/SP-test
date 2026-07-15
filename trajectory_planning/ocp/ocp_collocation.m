function defects = ocp_collocation(Z, params)
%OCP_COLLOCATION Hermite-Simpson 配点离散化缺陷
%   defects = ocp_collocation(Z, params) 计算所有配点段的 Simpson 积分缺陷
%
% 输入:
%   Z      - 决策变量向量 [x0(6); u0(3); x1(6); u1(3); ...; xN(6); uN(3); Tf]
%            每个节点占用 9 个元素 (6 状态 + 3 控制), 共 N+1 个节点, 末尾 1 个 Tf
%            总长度 = 9*(N+1) + 1
%   params - 配置参数结构体 (使用 params.N)
%
% 输出:
%   defects - 配点缺陷向量 (6*N x 1)
%
% 对每段 i in [1,N]:
%   f_{i-1} = dynamics_model(x_{i-1}, u_{i-1}, params)
%   f_i     = dynamics_model(x_i, u_i, params)
%   h       = Tf / N
%   Hermite 中点: x_m = (x_{i-1} + x_i)/2 + h/8 * (f_{i-1} - f_i)
%   u_m = (u_{i-1} + u_i) / 2
%   f_m = dynamics_model(x_m, u_m, params)
%   Simpson 缺陷: x_i - x_{i-1} - h/6 * (f_{i-1} + 4*f_m + f_i)

    N = params.N;
    Tf = Z(end);
    h = Tf / N;                       % 每段时间步长

    defects = zeros(6*N, 1);

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

        % Simpson 缺陷
        defects((i-1)*6 + 1 : i*6) = ...
            x_curr - x_prev - (h/6) * (f_prev + 4*f_mid + f_curr);
    end
end
