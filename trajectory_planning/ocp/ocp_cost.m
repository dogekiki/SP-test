function J = ocp_cost(Z, params)
%OCP_COST OCP 代价函数
%   J = ocp_cost(Z, params) 计算最优控制问题的代价
%
% 输入:
%   Z      - 决策变量向量 [x0(6); u0(3); ...; xN(6); uN(3); Tf] (9*(N+1)+1 x 1)
%   params - 配置参数结构体
%
% 输出:
%   J - 代价标量 = Tf + w_smooth * sum_{k=0}^{N} (u_k' * u_k) * h,  h = Tf/N
%
%   其中 Tf 为总飞行时间, w_smooth 为平滑性权重, h 为每段时间步长。
%   平滑项对所有配点控制量的平方和进行积分 (矩形近似)。

    N  = params.N;
    Tf = Z(end);
    h  = Tf / N;

    % 累加所有节点的控制能量 u_k' * u_k
    J_smooth = 0;
    for k = 0:N
        off = 9 * k;
        uk = Z(off + 7 : off + 9);
        J_smooth = J_smooth + (uk' * uk);
    end

    J = Tf + params.w_smooth * J_smooth * h;
end
