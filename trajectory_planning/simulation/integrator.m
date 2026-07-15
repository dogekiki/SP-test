function x_next = integrator(x, u, dt, params)
%INTEGRATOR 标准 RK4 (四阶 Runge-Kutta) 积分器
%   x_next = integrator(x, u, dt, params)
%
%   使用 RK4 方法对飞行器动力学模型进行一步积分:
%     k1 = f(x, u)
%     k2 = f(x + dt/2*k1, u)
%     k3 = f(x + dt/2*k2, u)
%     k4 = f(x + dt*k3, u)
%     x_next = x + dt/6*(k1 + 2*k2 + 2*k3 + k4)
%
% 输入:
%   x      - 当前状态 (6x1) [x;y;z;V;chi;gamma]
%   u      - 控制输入 (3x1), 在积分步内保持不变
%   dt     - 积分步长 [s]
%   params - 配置参数结构体
%
% 输出:
%   x_next - 下一时刻状态 (6x1)

    k1 = dynamics_model(x,               u, params);
    k2 = dynamics_model(x + dt/2*k1,     u, params);
    k3 = dynamics_model(x + dt/2*k2,     u, params);
    k4 = dynamics_model(x + dt*k3,       u, params);
    x_next = x + dt/6*(k1 + 2*k2 + 2*k3 + k4);
end
