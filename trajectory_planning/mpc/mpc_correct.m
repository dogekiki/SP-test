function [u_corr, replan_flag] = mpc_correct(x_actual, t_now, traj_ref, ctrl_ref, Tf, target_pos, params)
%MPC_CORRECT MPC 在线修正主函数
%   [u_corr, replan_flag] = mpc_correct(x_actual, t_now, traj_ref, ctrl_ref, Tf, target_pos, params)
%
%   从基准轨迹提取当前时刻参考, 在参考点处线性化并构建 QP, 求解最优控制修正量,
%   返回修正后的控制指令及重规划标志。
%
% 流程:
%   1. 从基准轨迹提取当前时刻参考状态/控制
%   2. 线性化: [Phi, Gamma] = mpc_linearize(x_ref, u_ref, params)
%   3. 状态偏差: dx0 = x_actual - x_ref
%   4. 构建 QP: [H, g, A_con, lb, ub] = mpc_build_qp(...)
%   5. 求解 QP: dU = quadprog(...), 失败则用零向量
%   6. 修正控制: u_corr = u_ref + dU(1:3)
%   7. 重规划判断: mpc_replan_trigger(t_now, Tf, 0, params)
%
% 输入:
%   x_actual    - 当前实际状态 (6x1)
%   t_now       - 当前时间 [s]
%   traj_ref    - 基准轨迹 [6 x (N+1)]
%   ctrl_ref    - 基准控制 [3 x (N+1)]
%   Tf          - 总飞行时间 [s]
%   target_pos  - 目标当前位置 (3x1) [本函数未直接使用, 保留接口]
%   params      - 配置参数结构体
%
% 输出:
%   u_corr      - 修正后的控制指令 (3x1)
%   replan_flag - 重规划标志 (1=需要, 0=不需要)

    %% 1. 从基准轨迹提取当前时刻参考
    N   = size(traj_ref, 2) - 1;       % 配置点数
    h   = Tf / N;                       % 配置时间间隔
    idx = max(1, min(floor(t_now / h) + 1, N + 1));
    x_ref = traj_ref(:, idx);
    u_ref = ctrl_ref(:, idx);

    %% 2. 线性化
    [Phi, Gamma] = mpc_linearize(x_ref, u_ref, params);

    %% 3. 状态偏差
    dx0 = x_actual - x_ref;

    %% 4. 构建 QP
    [H, g, A_con, lb, ub] = mpc_build_qp(Phi, Gamma, dx0, x_ref, u_ref, params);

    %% 5. 求解 QP
    %    mpc_build_qp 返回约束形式: lb <= A_con*dU <= ub
    %    A_con = [eye(n_du); rate_matrix], 上半部分为单位阵 (变量上下界),
    %    下半部分为增量约束 (线性不等式)。
    %    拆分为 quadprog 的变量上下界 + 线性不等式形式以提高数值稳定性。
    n_du = 3 * params.Nc;

    % 变量上下界 (来自 A_con 的单位阵部分)
    lb_dU = lb(1:n_du);
    ub_dU = ub(1:n_du);

    % 线性不等式 (来自 A_con 的增量约束部分): lb_rate <= A_rate*dU <= ub_rate
    %    转换为 A_ineq*dU <= b_ineq 形式
    n_con = size(A_con, 1);
    if n_con > n_du
        A_rate = A_con(n_du+1:end, :);
        lb_rate = lb(n_du+1:end);
        ub_rate = ub(n_du+1:end);
        A_ineq  = [A_rate; -A_rate];
        b_ineq  = [ub_rate; -lb_rate];
    else
        A_ineq = [];
        b_ineq = [];
    end

    [dU, ~, exitflag_qp] = quadprog(H, g, A_ineq, b_ineq, [], [], ...
        lb_dU, ub_dU, [], params.qp_opts);

    % QP 求解失败时使用零向量 (u_corr = u_ref)
    if exitflag_qp <= 0 || isempty(dU) || any(~isfinite(dU))
        dU = zeros(n_du, 1);
    end

    %% 6. 修正控制
    u_corr = u_ref + dU(1:3);

    %% 7. 重规划判断 (last_replan_time 暂用 0)
    replan_flag = mpc_replan_trigger(t_now, Tf, 0, params);
end
