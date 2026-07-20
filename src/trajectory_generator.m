function [x_ref, u_ref] = trajectory_generator(waypoints, cfg)
    % waypoint序列 → 平滑参考轨迹
    % waypoints: Nx3 矩阵 [px, py, pz]
    % 输出: x_ref(6, K), u_ref(3, K)
    
    dt = cfg.mpc.dt;
    T_total = cfg.sim.T_total;
    K = floor(T_total / dt);
    
    % 线性插值waypoint
    t_wp = linspace(0, T_total, size(waypoints,1));
    t_all = 0:dt:(K-1)*dt;
    
    px_ref = interp1(t_wp, waypoints(:,1), t_all, 'pchip');
    py_ref = interp1(t_wp, waypoints(:,2), t_all, 'pchip');
    pz_ref = interp1(t_wp, waypoints(:,3), t_all, 'pchip');
    
    % 数值微分求速度和角度
    V_ref = sqrt(diff(px_ref).^2 + diff(py_ref).^2 + diff(pz_ref).^2) / dt;
    V_ref = [V_ref; V_ref(end)];
    chi_ref = atan2(diff(py_ref), diff(px_ref));
    chi_ref = [chi_ref; chi_ref(end)];
    gamma_ref = atan2(diff(pz_ref), sqrt(diff(px_ref).^2 + diff(py_ref).^2));
    gamma_ref = [gamma_ref; gamma_ref(end)];
    
    x_ref = [px_ref; py_ref; pz_ref; V_ref; chi_ref; gamma_ref];
    
    % 参考控制输入 (近似)
    u_ref = zeros(3, K);
    u_ref(1,:) = 0.5 * cfg.aircraft.rho * V_ref.^2 * cfg.aircraft.S * cfg.aircraft.CD0;
    u_ref(2,:) = [diff(chi_ref)/dt; 0];
    u_ref(3,:) = [diff(gamma_ref)/dt; 0];
end
