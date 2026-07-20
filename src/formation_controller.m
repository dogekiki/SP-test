function [u_all, info] = formation_controller(x_all, x_ref_leader_window, u_ref_leader_window, cfg)
    % 3机Leader-Follower编队控制
    n_drones = cfg.formation.n_drones;
    u_all = zeros(3, n_drones);
    solve_times = zeros(1, n_drones);
    
    [u_all(:,1), info_leader] = mpc_controller(x_all(:,1), x_ref_leader_window, u_ref_leader_window, cfg);
    solve_times(1) = info_leader.solve_time;
    
    for i = 2:n_drones
        offset = cfg.formation.offsets(i, :)';
        offset_full = [offset; 0; 0; 0];
        x_ref_follower = x_ref_leader_window + offset_full;
        u_ref_follower = u_ref_leader_window;
        [u_all(:,i), info_f] = mpc_controller(x_all(:,i), x_ref_follower, u_ref_follower, cfg);
        solve_times(i) = info_f.solve_time;
    end
    
    info.total_solve_time = sum(solve_times);
    info.max_solve_time = max(solve_times);
    info.solve_times = solve_times;
end
