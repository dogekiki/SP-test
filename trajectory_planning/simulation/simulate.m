function results = simulate(x0, u0, target_init, target_vel, params)
%SIMULATE 飞行器轨迹规划闭环仿真主循环
%   results = simulate(x0, u0, target_init, target_vel, params)
%
%   流程:
%     1. 离线 OCP 求解基准轨迹
%     2. 闭环仿真: MPC 在线修正 + RK4 积分 + 重规划
%     3. 拦截判定与超时检查
%
% 输入:
%   x0          - 初始状态 (6x1) [x;y;z;V;chi;gamma]
%   u0          - 初始控制 (3x1) [chi_dot;gamma_dot;V_dot]
%   target_init - 目标初始位置 (3x1)
%   target_vel  - 目标常速度 (3x1)
%   params      - 配置参数结构体
%
% 输出:
%   results - 仿真结果结构体:
%     .t              - 时间向量 (Tx1)
%     .states         - 状态历史 (6xT), 每列一个时间步
%     .controls       - 控制历史 (3xT)
%     .target_states  - 目标位置历史 (3xT)
%     .intercepted    - 拦截成功标志 (bool)
%     .intercept_dist - 拦截距离 [m] (float, 未拦截时为 Inf)
%     .Tf             - 初始 OCP 总飞行时间 [s]
%     .ocp_info       - 初始 OCP 求解信息

    %% 1. 离线 OCP 求解基准轨迹
    fprintf('[simulate] 求解离线 OCP...\n');
    [traj_ref, ctrl_ref, Tf, info] = plan_offline_OCP(x0, u0, target_init, target_vel, params);
    fprintf('[simulate] OCP 完成: Tf=%.2f s, exitflag=%d, cost=%.4f\n', Tf, info.exitflag, info.cost);

    %% 2. 初始化
    dt_mpc = params.dt_mpc;
    t_max  = 300;
    t      = 0;
    x      = x0;
    last_replan_time   = 0;
    traj_ref_current   = traj_ref;
    ctrl_ref_current   = ctrl_ref;
    Tf_current         = Tf;

    % 预分配存储 (足够 t_max/dt_mpc 步, 不够再扩容)
    max_steps = ceil(t_max / dt_mpc) + 10;
    t_log             = zeros(max_steps, 1);
    states_log        = zeros(6, max_steps);
    controls_log      = zeros(3, max_steps);
    target_states_log = zeros(3, max_steps);
    step = 0;

    intercepted   = false;
    intercept_dist = Inf;

    %% 3. 仿真循环
    while t < t_max
        % a. 目标当前位置
        target_pos = target_model(t, target_init, target_vel);

        % b. MPC 在线修正
        %    传入相对于上次重规划的时间, 使参考索引与重规划触发正确工作
        t_ref = t - last_replan_time;
        [u_corr, replan_flag] = mpc_correct(x, t_ref, traj_ref_current, ...
            ctrl_ref_current, Tf_current, target_pos, params);

        % 安全限幅: 确保控制指令在约束范围内
        u_corr(1) = max(-params.chi_dot_max,   min(params.chi_dot_max,   u_corr(1)));
        u_corr(2) = max(-params.gamma_dot_max, min(params.gamma_dot_max, u_corr(2)));
        u_corr(3) = max(-params.V_dot_max,     min(params.V_dot_max,     u_corr(3)));

        % c. 重规划判定
        if replan_flag && (t - last_replan_time) >= params.replan_min_interval
            fprintf('[simulate] t=%.1f 触发重规划 (距上次 %.1f s)...\n', t, t - last_replan_time);
            [traj_ref_current, ctrl_ref_current, Tf_current, ~] = ...
                plan_offline_OCP(x, u_corr, target_pos, target_vel, params);
            last_replan_time = t;
            fprintf('[simulate] 重规划完成: Tf=%.2f s\n', Tf_current);
        end

        % d. RK4 积分
        x = integrator(x, u_corr, dt_mpc, params);

        % 安全限幅: 速度、航迹角与高度约束
        x(4) = max(params.V_min,            min(params.V_max,       x(4)));
        x(6) = max(-params.gamma_max,       min(params.gamma_max,   x(6)));
        x(3) = max(params.z_min,                                    x(3));

        % e. 目标新位置
        target_pos_new = target_model(t + dt_mpc, target_init, target_vel);

        % f. 时间推进
        t = t + dt_mpc;

        % g. 记录
        step = step + 1;
        t_log(step)             = t;
        states_log(:, step)     = x;
        controls_log(:, step)   = u_corr;
        target_states_log(:, step) = target_pos_new;

        % h. 拦截判定
        dist = norm(x(1:3) - target_pos_new);
        if dist <= params.d_capture
            intercepted   = true;
            intercept_dist = dist;
            fprintf('[simulate] 拦截成功! t=%.2f s, dist=%.2f m\n', t, dist);
            break;
        end

        % i. 超时检查
        if t > t_max
            break;
        end

        % 进度输出 (每 10 秒一次)
        if mod(step, round(10 / dt_mpc)) == 0
            fprintf('[simulate] t=%.1f s, dist=%.1f m\n', t, dist);
        end

        % 动态扩容 (以防预分配空间不足)
        if step >= max_steps
            max_steps = max_steps * 2;
            t_log             = [t_log;             zeros(max_steps - numel(t_log), 1)];
            states_log        = [states_log,        zeros(6, max_steps - size(states_log, 2))];
            controls_log      = [controls_log,      zeros(3, max_steps - size(controls_log, 2))];
            target_states_log = [target_states_log, zeros(3, max_steps - size(target_states_log, 2))];
        end
    end

    if ~intercepted
        fprintf('[simulate] 仿真结束 (未拦截): t=%.2f s, 最终距离=%.2f m\n', t, dist);
    end

    %% 4. 截断未使用的预分配空间
    t_log             = t_log(1:step);
    states_log        = states_log(:, 1:step);
    controls_log      = controls_log(:, 1:step);
    target_states_log = target_states_log(:, 1:step);

    %% 5. 输出结果
    results.t              = t_log;
    results.states         = states_log;
    results.controls       = controls_log;
    results.target_states  = target_states_log;
    results.intercepted    = intercepted;
    results.intercept_dist = intercept_dist;
    results.Tf             = Tf;
    results.ocp_info       = info;
end
