function [A, B] = ltv_linearize(x_ref, u_ref, p, dt)
    % 数值Jacobian线性化 + 前向欧拉离散化
    % A = I + (df/dx) * dt
    % B = (df/du) * dt
    
    n = 6; m = 3;
    eps = 1e-6;
    
    f0 = dynamics_3dof(x_ref, u_ref, p);
    
    A_cont = zeros(n, n);
    for i = 1:n
        x_pert = x_ref; x_pert(i) = x_pert(i) + eps;
        f_pert = dynamics_3dof(x_pert, u_ref, p);
        A_cont(:, i) = (f_pert - f0) / eps;
    end
    
    B_cont = zeros(n, m);
    for i = 1:m
        u_pert = u_ref; u_pert(i) = u_pert(i) + eps;
        f_pert = dynamics_3dof(x_ref, u_pert, p);
        B_cont(:, i) = (f_pert - f0) / eps;
    end
    
    A = eye(n) + A_cont * dt;
    B = B_cont * dt;
end
