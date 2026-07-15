function dxdt = dynamics_model(x, u, params)
%DYNAMICS_MODEL 飞行器质点动力学模型
%   dxdt = dynamics_model(x, u, params) 计算状态导数
%
% 输入:
%   x      - 状态向量 [x; y; z; V; chi; gamma] (6x1)
%            x(1)=x 位置 [m]
%            x(2)=y 位置 [m]
%            x(3)=z 高度 [m]
%            x(4)=V 速度 [m/s]
%            x(5)=chi 航向角 [rad]
%            x(6)=gamma 航迹倾斜角 [rad]
%   u      - 控制向量 [chi_dot; gamma_dot; V_dot] (3x1)
%            u(1)=chi_dot   航向角速率 [rad/s]
%            u(2)=gamma_dot 倾斜角速率 [rad/s]
%            u(3)=V_dot     速度变化率 [m/s^2]
%   params - 配置参数结构体 (本模型未直接使用，保留接口一致性)
%
% 输出:
%   dxdt   - 状态导数 [dx; dy; dz; dV; dchi; dgamma] (6x1)

    V     = x(4);
    chi   = x(5);
    gamma = x(6);

    % 位置导数
    dx    = V * cos(gamma) * cos(chi);
    dy    = V * cos(gamma) * sin(chi);
    dz    = V * sin(gamma);

    % 速度导数
    dV    = u(3);

    % 角度导数
    dchi   = u(1);
    dgamma = u(2);

    dxdt = [dx; dy; dz; dV; dchi; dgamma];
end
