function pos = target_model(t, target_init, target_vel)
%TARGET_MODEL 目标匀速直线运动模型
%   pos = target_model(t, target_init, target_vel) 计算目标在时刻 t 的位置
%
% 输入:
%   t           - 时间标量 [s]
%   target_init - 目标初始位置 [x; y; z] (3x1)
%   target_vel  - 目标常速度 [vx; vy; vz] (3x1)
%
% 输出:
%   pos - 目标在时刻 t 的位置 [x; y; z] (3x1)
%
% 模型: pos = target_init + target_vel * t  (匀速直线运动)

    pos = target_init + target_vel * t;
end
