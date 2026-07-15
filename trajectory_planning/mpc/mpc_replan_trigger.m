function replan_flag = mpc_replan_trigger(t_now, Tf, last_replan_time, params)
%MPC_REPLAN_TRIGGER 判断是否需要触发 MPC 重规划
%   replan_flag = mpc_replan_trigger(t_now, Tf, last_replan_time, params)
%
%   触发条件 (同时满足):
%     1. 当前时间超过飞行时间的阈值比例: t_now > replan_threshold * Tf
%     2. 距上次重规划的时间间隔足够: (t_now - last_replan_time) >= replan_min_interval
%
% 输入:
%   t_now             - 当前时间 [s]
%   Tf                - 总飞行时间 [s]
%   last_replan_time  - 上次重规划时间 [s]
%   params            - 配置参数结构体
%     .replan_threshold    - 重规划阈值比例 (默认 0.8)
%     .replan_min_interval - 最小重规划间隔 [s]
%
% 输出:
%   replan_flag - 1 表示需要重规划, 0 表示不需要

    cond_time = t_now > params.replan_threshold * Tf;
    cond_interval = (t_now - last_replan_time) >= params.replan_min_interval;
    replan_flag = cond_time && cond_interval;
end
