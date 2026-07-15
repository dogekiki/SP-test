function [Phi, Gamma] = mpc_linearize(x_ref, u_ref, params)
%MPC_LINEARIZE 在参考点处线性化并离散化飞行器动力学
%   [Phi, Gamma] = mpc_linearize(x_ref, u_ref, params)
%
%   在参考状态 x_ref 和参考控制 u_ref 处调用 jacobian_dynamics 得到
%   连续时间雅可比矩阵 A (6x6) 和 B (6x3)，然后使用前向欧拉法离散化:
%     Phi   = I + A * dt_mpc   (6x6)  离散状态转移矩阵
%     Gamma = B * dt_mpc       (6x3)  离散控制输入矩阵
%
% 输入:
%   x_ref  - 参考状态 [x;y;z;V;chi;gamma] (6x1)
%   u_ref  - 参考控制 [chi_dot;gamma_dot;V_dot] (3x1)
%   params - 配置参数结构体 (使用 dt_mpc 字段)
%
% 输出:
%   Phi   - 离散状态转移矩阵 (6x6)
%   Gamma - 离散控制输入矩阵 (6x3)

    % 连续时间雅可比
    [A, B] = jacobian_dynamics(x_ref, u_ref, params);

    % 前向欧拉离散化
    dt = params.dt_mpc;
    Phi   = eye(6) + A * dt;
    Gamma = B * dt;
end
