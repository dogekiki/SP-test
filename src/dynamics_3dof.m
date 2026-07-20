function dxdt = dynamics_3dof(x, u, p)
    % 3-DOF质点动力学模型
    % 状态: x = [px, py, pz, V, chi, gamma]
    % 控制: u = [T, chi_dot, gamma_dot]
    % 参数: p = struct(m, S, rho, g, CD0)
    
    V = x(4); chi = x(5); gamma = x(6);
    T = u(1); chi_dot = u(2); gamma_dot = u(3);
    
    % 气动力
    q = 0.5 * p.rho * V^2 * p.S;  % 动压
    D = q * p.CD0;                 % 阻力
    
    % 运动方程
    dxdt = [V * cos(gamma) * cos(chi);   % dpx/dt
            V * cos(gamma) * sin(chi);   % dpy/dt
            V * sin(gamma);               % dpz/dt
            (T - D) / p.m - p.g * sin(gamma);  % dV/dt
            chi_dot;                       % dchi/dt
            gamma_dot];                    % dgamma/dt
end
