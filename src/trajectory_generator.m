function [x_ref, u_ref] = trajectory_generator(waypoints, cfg)
    % waypoint序列 → 平滑可行参考轨迹
    % waypoints: Nx3 矩阵 [px, py, pz]
    % 输出: x_ref(6, K), u_ref(3, K)
    % 方法: 转角平滑(圆弧近似) + pchip插值 + 弧长重参数化(恒速)

    dt = cfg.mpc.dt;
    T_total = cfg.sim.T_total;
    K = floor(T_total / dt);

    % 0. 转角平滑: 在航点处插入中间点创建圆弧转弯
    V_est = 15;  % 估计速度用于计算转弯半径
    r_turn = max(V_est / cfg.constraints.chi_dot_max, 50);  % 最小转弯半径
    wp_smooth = smooth_corners(waypoints, r_turn);

    % 1. 密集pchip插值生成路径几何 (10倍过采样)
    t_wp = linspace(0, 1, size(wp_smooth,1));
    t_dense = linspace(0, 1, K * 10);
    px_dense = interp1(t_wp, wp_smooth(:,1), t_dense, 'pchip');
    py_dense = interp1(t_wp, wp_smooth(:,2), t_dense, 'pchip');
    pz_dense = interp1(t_wp, wp_smooth(:,3), t_dense, 'pchip');

    % 2. 计算累积弧长
    dx = diff(px_dense);
    dy = diff(py_dense);
    dz = diff(pz_dense);
    ds = sqrt(dx.^2 + dy.^2 + dz.^2);
    s_cum = [0, cumsum(ds)];
    total_length = s_cum(end);

    % 3. 恒速重参数化: 按弧长均匀采样
    V_const = total_length / T_total;
    s_ref = (0:K-1) * dt * V_const;
    s_ref = min(s_ref, total_length);

    % 4. 按弧长插值位置
    px_ref = interp1(s_cum, px_dense, s_ref, 'pchip');
    py_ref = interp1(s_cum, py_dense, s_ref, 'pchip');
    pz_ref = interp1(s_cum, pz_dense, s_ref, 'pchip');

    px_ref = px_ref(:)'; py_ref = py_ref(:)'; pz_ref = pz_ref(:)';

    % 5. 数值微分求速度和角度
    V_ref = sqrt(diff(px_ref).^2 + diff(py_ref).^2 + diff(pz_ref).^2) / dt;
    V_ref = [V_ref, V_ref(end)];

    chi_ref = atan2(diff(py_ref), diff(px_ref));
    chi_ref = [chi_ref, chi_ref(end)];
    chi_ref = unwrap(chi_ref);

    gamma_ref = atan2(diff(pz_ref), sqrt(diff(px_ref).^2 + diff(py_ref).^2));
    gamma_ref = [gamma_ref, gamma_ref(end)];

    x_ref = [px_ref; py_ref; pz_ref; V_ref; chi_ref; gamma_ref];

    % 6. 参考控制输入
    u_ref = zeros(3, K);
    % 推力 = 阻力 + 重力分量 (维持恒速所需推力)
    D_ref = 0.5 * cfg.aircraft.rho * V_ref.^2 * cfg.aircraft.S * cfg.aircraft.CD0;
    gravity_term = cfg.aircraft.m * cfg.aircraft.g * sin(gamma_ref);
    u_ref(1,:) = D_ref + gravity_term;
    % 限幅到可行范围
    u_ref(1,:) = max(min(u_ref(1,:), cfg.constraints.T_max), cfg.constraints.T_min);

    chi_dot_raw = [diff(chi_ref)/dt, 0];
    chi_dot_max = cfg.constraints.chi_dot_max;
    chi_dot_ref = max(min(chi_dot_raw, chi_dot_max), -chi_dot_max);
    chi_dot_ref = smooth_signal(chi_dot_ref, 5);

    gamma_dot_raw = [diff(gamma_ref)/dt, 0];
    gamma_dot_max = cfg.constraints.gamma_dot_max;
    gamma_dot_ref = max(min(gamma_dot_raw, gamma_dot_max), -gamma_dot_max);
    gamma_dot_ref = smooth_signal(gamma_dot_ref, 5);

    u_ref(2,:) = chi_dot_ref;
    u_ref(3,:) = gamma_dot_ref;
end

function wp_smooth = smooth_corners(waypoints, r_turn)
    % 在航点转角处插入中间点, 创建圆弧近似转弯
    n = size(waypoints, 1);
    if n < 3
        wp_smooth = waypoints;
        return;
    end

    wp_smooth = waypoints(1, :);
    for i = 2:n-1
        p_prev = waypoints(i-1, :);
        p_curr = waypoints(i, :);
        p_next = waypoints(i+1, :);

        d1 = p_curr - p_prev;
        d1 = d1 / max(norm(d1), 1e-10);
        d2 = p_next - p_curr;
        d2 = d2 / max(norm(d2), 1e-10);

        cos_theta = max(min(dot(d1, d2), 1), -1);
        theta = acos(cos_theta);

        if theta < 0.1  % 近似直线, 无需平滑
            wp_smooth = [wp_smooth; p_curr];
            continue;
        end

        % 转弯前后距离
        d = r_turn * tan(theta / 2);
        seg1_len = norm(p_curr - p_prev);
        seg2_len = norm(p_next - p_curr);
        d = min([d, seg1_len * 0.4, seg2_len * 0.4]);

        p_before = p_curr - d1 * d;
        p_after = p_curr + d2 * d;

        wp_smooth = [wp_smooth; p_before; p_after];
    end
    wp_smooth = [wp_smooth; waypoints(n, :)];
end

function y = smooth_signal(x, win)
    n = length(x);
    y = zeros(1, n);
    half = floor(win / 2);
    for i = 1:n
        lo = max(1, i - half);
        hi = min(n, i + half);
        y(i) = mean(x(lo:hi));
    end
end
