function [A, B] = jacobian_dynamics(x, u, params)
%JACOBIAN_DYNAMICS 飞行器动力学的解析雅可比矩阵
%   [A, B] = jacobian_dynamics(x, u, params) 返回连续时间系统 dx/dt=f(x,u)
%   对状态 x 的雅可比 A (6x6) 和对控制 u 的雅可比 B (6x3)
%
% 状态 x = [x; y; z; V; chi; gamma]
% 控制 u = [chi_dot; gamma_dot; V_dot]
%
% 动力学:
%   dx/dt    = V*cos(gamma)*cos(chi)
%   dy/dt    = V*cos(gamma)*sin(chi)
%   dz/dt    = V*sin(gamma)
%   dV/dt    = u(3)
%   dchi/dt  = u(1)
%   dgamma/dt= u(2)
%
% 输出:
%   A - 状态雅可比 d f / d x  (6x6)
%   B - 控制雅可比 d f / d u  (6x3)

    V     = x(4);
    chi   = x(5);
    gamma = x(6);

    cg = cos(gamma);
    sg = sin(gamma);
    cc = cos(chi);
    sc = sin(chi);

    %% 状态雅可比 A (6x6)
    % 前 3 列 (对 x, y, z) 全为零
    A = zeros(6,6);

    % 第 4 列: 对 V 的偏导
    A(1,4) = cg * cc;
    A(2,4) = cg * sc;
    A(3,4) = sg;

    % 第 5 列: 对 chi 的偏导
    A(1,5) = -V * cg * sc;
    A(2,5) =  V * cg * cc;
    A(3,5) =  0;

    % 第 6 列: 对 gamma 的偏导
    A(1,6) = -V * sg * cc;
    A(2,6) = -V * sg * sc;
    A(3,6) =  V * cg;

    % 第 4-6 行 (dV, dchi, dgamma) 对状态偏导全为零，已由 zeros 初始化

    %% 控制雅可比 B (6x3)
    B = zeros(6,3);
    B(4,3) = 1;   % dV/dV_dot
    B(5,1) = 1;   % dchi/dchi_dot
    B(6,2) = 1;   % dgamma/dgamma_dot
end
