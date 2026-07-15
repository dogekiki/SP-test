function [J, gradJ] = ocp_cost(Z, params)
%OCP_COST OCP 代价函数 (含可选解析梯度)
%   J = ocp_cost(Z, params)                  -> 仅代价
%   [J, gradJ] = ocp_cost(Z, params)         -> 代价 + 梯度
%
% 输入:
%   Z      - 决策变量向量 [x0(6); u0(3); ...; xN(6); uN(3); Tf] (9*(N+1)+1 x 1)
%   params - 配置参数结构体
%
% 输出:
%   J     - 代价标量 = Tf + w_smooth * sum_{k=0}^{N} (u_k' * u_k) * h,  h = Tf/N
%   gradJ - (可选) 代价对 Z 的梯度 (nZ x 1), 仅当 nargout>=2 时计算
%
%   梯度:
%     dJ/dx_k   = 0
%     dJ/du_k   = 2 * w_smooth * h * u_k
%     dJ/dTf    = 1 + w_smooth * (1/N) * sum_k(u_k' * u_k)

    N  = params.N;
    Tf = Z(end);
    h  = Tf / N;
    nZ = numel(Z);

    % 累加所有节点的控制能量 u_k' * u_k
    sum_u2 = 0;
    for k = 0:N
        off = 9 * k;
        uk = Z(off + 7 : off + 9);
        sum_u2 = sum_u2 + (uk' * uk);
    end

    J = Tf + params.w_smooth * sum_u2 * h;

    if nargout >= 2
        gradJ = zeros(nZ, 1);
        % 对控制的偏导
        for k = 0:N
            off = 9 * k;
            gradJ(off + 7 : off + 9) = 2 * params.w_smooth * h * Z(off + 7 : off + 9);
        end
        % 对 Tf 的偏导: d/dTf [ Tf + w_smooth * sum_u2 * (Tf/N) ]
        %             = 1 + w_smooth * sum_u2 / N
        gradJ(end) = 1 + params.w_smooth * sum_u2 / N;
        % 对状态的偏导为 0 (已初始化)
    end
end
