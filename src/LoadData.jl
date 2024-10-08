function read_WCA_simulation(filenamefull, dt; maxt=-1, every=1, original=false)
    println("Reading data file")
    f = open(filenamefull)
    r = Array{Array{Float64, 2}, 1}()
    F = Array{Array{Float64, 2}, 1}()
    t = Vector{Float64}()
    iter = eachline(f)
    box_size = 0
    timestep = -1
    for line in iter
        if line == "ITEM: TIMESTEP"
            timestep += 1

            if length(r) >= maxt && maxt > 0
                break
            end
            push!(t, parse(Int64, iterate(iter)[1]))
            if timestep % every != 0
                continue
            end
            if length(r) % 100 == 0
                println(length(r), " snapshots found.")
            end
            _ = iterate(iter) # ITEM:NUMBER OF ATOMS
            N = parse(Int64, iterate(iter)[1])
            _ = iterate(iter) # ITEM: BOX BOUNDS
            box_size = parse(Float64, split(iterate(iter)[1])[2])
            _ = iterate(iter)
            _ = iterate(iter)
            _ = iterate(iter) # ITEM: ATOMS
            rnew = zeros(N, 3)
            fnew = zeros(N, 3)
            for i = 1:N
                index = Parsers.parse(Int64, readuntil(f, ' '))
                # if timestep == 0
                #     readuntil(f, ' ')
                # end

                for j = 1:3
                    rnew[index, j] = Parsers.parse(Float64, readuntil(f, ' '))
                end
                for j = 1:2
                    fnew[index, j] = Parsers.parse(Float64, readuntil(f, ' '))  
                end
                fnew[index, 3] = Parsers.parse(Float64, readline(f))  
                # readline(f)
            end
            push!(r, rnew)
            push!(F, fnew)
        end
    end
    close(f)
    box_sizes = [box_size, box_size, box_size]
    t .-= 1
    println(length(r), " timesteps found with ", size(r[1])[1], " atoms.")
    r = reshape_data(r)
    remap_positions!(r, box_sizes)
    if original
        r = find_original_trajectories(r, box_sizes)
    end
    F = reshape_data(F)
    D = ones(N)
    N = size(F, 2)
    v = zeros(size(F)...)
    dt_arr, t1_t2_pair_array = find_allowed_t1_t2_pair_array_quasilog(t;doublefactor=200)
    # dt_arr = [t[i]-t[1] for i in 1:length(t)]
    # t1_t2_pair_array = [[1;; i] for i in 1:length(t)]
    s = SingleComponentSimulation(N, 3, r, v, F, D, t*dt , box_sizes, dt_arr , t1_t2_pair_array, filenamefull)
    return s
end

function read_Newtonian_KAWCA_simulation(filenamefull, dt; maxt=-1, every=1, original=false)
    println("Reading data file")
    f = open(filenamefull)
    r = Array{Array{Float64, 2}, 1}()
    v = Array{Array{Float64, 2}, 1}()
    types_array = Array{Array{Int, 1}, 1}()
    t = Vector{Float64}()
    iter = eachline(f)
    box_size = 0
    timestep = -1
    for line in iter
        if line == "ITEM: TIMESTEP"
            timestep += 1

            if length(r) >= maxt && maxt > 0
                break
            end
            push!(t, parse(Int64, iterate(iter)[1]))
            if timestep % every != 0
                continue
            end
            if length(r) % 100 == 0
                println(length(r), " snapshots found.")
            end
            _ = iterate(iter) # ITEM:NUMBER OF ATOMS
            N = parse(Int64, iterate(iter)[1])
            _ = iterate(iter) # ITEM: BOX BOUNDS
            box_size = parse(Float64, split(iterate(iter)[1])[2])
            _ = iterate(iter)
            _ = iterate(iter)
            _ = iterate(iter) # ITEM: ATOMS
            rnew = zeros(N, 3)
            vnew = zeros(N, 3)
	        types = zeros(Int, N)
            for i = 1:N
                index = Parsers.parse(Int64, readuntil(f, ' '))
                types[index] = Parsers.parse(Int64, readuntil(f, ' '))
                # if timestep == 0
                #     readuntil(f, ' ')
                # end

                for j = 1:3
                    rnew[index, j] = Parsers.parse(Float64, readuntil(f, ' '))
                end
                for j = 1:2
                    vnew[index, j] = Parsers.parse(Float64, readuntil(f, ' '))  
                end
                vnew[index, 3] = Parsers.parse(Float64, readline(f))  
                # readline(f)
            end
            push!(r, rnew)
            push!(v, vnew)
            if length(types_array) == 0
                 push!(types_array, types)
            end
        end
    end
    close(f)
    box_sizes = [box_size, box_size, box_size]
    t .-= 1
    println(length(r), " timesteps found with ", size(r[1])[1], " atoms.")
    r = reshape_data(r)
    remap_positions!(r, box_sizes)
    if original
        r = find_original_trajectories(r, box_sizes)
    end
    v = reshape_data(v)
    types = types_array[1]
    #dt_arr, t1_t2_pair_array = find_allowed_t1_t2_pair_array(t;doublefactor=200)
    dt_arr = Int.([t[i]-t[1] for i in 1:length(t)])
    t1_t2_pair_array = [[1;; i] for i in 1:length(t)]
    F = zeros(size(v)...)
    rvec = separate_trajectories(r, types)
    vvec = separate_trajectories(v, types)
    Fvec = separate_trajectories(F, types)
    s = MultiComponentSimulation(sum(size.(rvec,2)), 
                            3, 
                            length(rvec), 
                            size.(rvec,2),
                            rvec,
                            vvec,
                            Fvec,
                            t*dt,
                            box_sizes,
                            dt_arr,
                            t1_t2_pair_array,
                            filenamefull
                            )
    return s
end

function read_Brownian_KALJ_simulation(filenamefull, dt; maxt=-1, every=1, original=false, forces=true)
    println("Reading data file")
    f = open(filenamefull)
    r = Array{Array{Float64, 2}, 1}()
    # v = Array{Array{Float64, 2}, 1}()
    types_array = Array{Array{Int, 1}, 1}()
    t = Vector{Float64}()
    iter = eachline(f)
    box_size = 0
    timestep = -1
    for line in iter
        if line == "ITEM: TIMESTEP"
            timestep += 1

            if length(r) >= maxt && maxt > 0
                break
            end
            push!(t, parse(Int64, iterate(iter)[1]))
            if timestep % every != 0
                continue
            end
            if length(r) % 100 == 0
                println(length(r), " snapshots found.")
            end
            _ = iterate(iter) # ITEM:NUMBER OF ATOMS
            N = parse(Int64, iterate(iter)[1])
            _ = iterate(iter) # ITEM: BOX BOUNDS
            box_size = parse(Float64, split(iterate(iter)[1])[2])
            _ = iterate(iter)
            _ = iterate(iter)
            _ = iterate(iter) # ITEM: ATOMS
            rnew = zeros(N, 3)
            # vnew = zeros(N, 3)
	        types = zeros(Int, N)
            for i = 1:N
                index = Parsers.parse(Int64, readuntil(f, ' '))
                types[index] = Parsers.parse(Int64, readuntil(f, ' '))

                for j = 1:2
                    rnew[index, j] = Parsers.parse(Float64, readuntil(f, ' '))
                end
                rnew[index, 3] = Parsers.parse(Float64, readline(f))  


            end
            push!(r, rnew)
            if length(types_array) == 0
                 push!(types_array, types)
            end
        end
    end
    close(f)
    box_sizes = [box_size, box_size, box_size]
    println(length(r), " timesteps found with ", size(r[1])[1], " atoms.")
    r = reshape_data(r)
    remap_positions!(r, box_sizes)
    if original
        r = find_original_trajectories(r, box_sizes)
    end
    types = types_array[1]
    dt_arr, t1_t2_pair_array = find_allowed_t1_t2_pair_array_quasilog(t;doublefactor=10)
    #dt_arr = Int.([t[i]-t[1] for i in 1:length(t)])
    #t1_t2_pair_array = [[1;; i] for i in 1:length(t)]
    F = zeros(size(r)...)
    v = zeros(size(r)...)

    rvec = separate_trajectories(r, types)
    vvec = separate_trajectories(v, types)
    Fvec = separate_trajectories(F, types)
    U = KAWCA(1.0, 1.5,0.5,1.0,0.8,0.88)

    s = MultiComponentSimulation(sum(size.(rvec,2)), 
                            3, 
                            length(rvec), 
                            size.(rvec,2),
                            rvec,
                            vvec,
                            Fvec,
                            t*dt,
                            box_sizes,
                            dt_arr,
                            t1_t2_pair_array,
                            filenamefull
                            )
    if forces
        println("Computing Forces")
        calculate_forces!(s, U; cutoff=2.5)
    end
    return s
end


function read_Brownian_KAWCA_simulation(filenamefull, dt; maxt=-1, every=1, original=false, forces=true)
    println("Reading data file")
    f = open(filenamefull)
    r = Array{Array{Float64, 2}, 1}()
    # v = Array{Array{Float64, 2}, 1}()
    types_array = Array{Array{Int, 1}, 1}()
    t = Vector{Float64}()
    iter = eachline(f)
    box_size = 0
    timestep = -1
    for line in iter
        if line == "ITEM: TIMESTEP"
            timestep += 1

            if length(r) >= maxt && maxt > 0
                break
            end
            push!(t, parse(Int64, iterate(iter)[1]))
            if timestep % every != 0
                continue
            end
            if length(r) % 100 == 0
                println(length(r), " snapshots found.")
            end
            _ = iterate(iter) # ITEM:NUMBER OF ATOMS
            N = parse(Int64, iterate(iter)[1])
            _ = iterate(iter) # ITEM: BOX BOUNDS
            box_size = parse(Float64, split(iterate(iter)[1])[2])
            _ = iterate(iter)
            _ = iterate(iter)
            _ = iterate(iter) # ITEM: ATOMS
            rnew = zeros(N, 3)
            # vnew = zeros(N, 3)
	        types = zeros(Int, N)
            for i = 1:N
                index = Parsers.parse(Int64, readuntil(f, ' '))
                types[index] = Parsers.parse(Int64, readuntil(f, ' '))

                for j = 1:2
                    rnew[index, j] = Parsers.parse(Float64, readuntil(f, ' '))
                end
                rnew[index, 3] = Parsers.parse(Float64, readline(f))  


            end
            push!(r, rnew)
            if length(types_array) == 0
                 push!(types_array, types)
            end
        end
    end
    close(f)
    box_sizes = [box_size, box_size, box_size]
    println(length(r), " timesteps found with ", size(r[1])[1], " atoms.")
    r = reshape_data(r)
    remap_positions!(r, box_sizes)
    if original
        r = find_original_trajectories(r, box_sizes)
    end
    types = types_array[1]
    dt_arr, t1_t2_pair_array = find_allowed_t1_t2_pair_array_quasilog(t;doublefactor=10)
    #dt_arr = Int.([t[i]-t[1] for i in 1:length(t)])
    #t1_t2_pair_array = [[1;; i] for i in 1:length(t)]
    F = zeros(size(r)...)
    v = zeros(size(r)...)

    rvec = separate_trajectories(r, types)
    vvec = separate_trajectories(v, types)
    Fvec = separate_trajectories(F, types)
    U = KAWCA(1.0, 1.5,0.5,1.0,0.8,0.88)

    s = MultiComponentSimulation(sum(size.(rvec,2)), 
                            3, 
                            length(rvec), 
                            size.(rvec,2),
                            rvec,
                            vvec,
                            Fvec,
                            t*dt,
                            box_sizes,
                            dt_arr,
                            t1_t2_pair_array,
                            filenamefull
                            )
    if forces
        println("Computing Forces")
        calculate_forces!(s, U; cutoff=2.0^(1.0/6.0))
    end
    return s
end

function read_monodisperse_hard_sphere_simulation(filename; original=false, velocities=false, forcestype=false, dtarr=true)
    # println("Reading data file")
    f = h5open(filename)
    saved_at_times = sort(parse.(Int64, keys(f["positions"])))
    Ndims, N = size(read(f["positions"][string(saved_at_times[1])]))

    
    box_size = read(HDF5.attributes(f)["box_size"])
    dt = float(read(HDF5.attributes(f)["Δt"]))
    dt = ifelse(dt == 0.0, 1.0, dt)
    m = 0.0
    try
        m += read(HDF5.attributes(f)["m"])
    catch
        m += 1.0
    end
    kBT = float(read(HDF5.attributes(f)["kBT"]))


    r = zeros(Ndims, N, length(saved_at_times))
    if velocities
         v = zeros(Ndims, N, length(saved_at_times))
    else
         v = zeros(1,1,1)
    end
    if forcestype != false
         F = zeros(Ndims, N, length(saved_at_times))
    else
         F = zeros(1,1,1)
    end
    D = zeros(N)

    if "diameters" in keys(f["diameters"])
        D .= read(f["diameters"]["diameters"])
    else
        D .= read(f["diameters"]["0"])
    end

    N_written = 0
    for t in saved_at_times
        N_written += 1
        r[:, :, N_written] .= read(f["positions"][string(t)])
        if velocities
            v[:, :, N_written] .= read(f["velocities"][string(t)])
        end
    end

    close(f)
    box_sizes = [box_size for i = 1:Ndims]
    if original
        r = find_original_trajectories(r, box_sizes)
    end
    if dtarr
        dt_arr, t1_t2_pair_array = find_allowed_t1_t2_pair_array_quasilog(saved_at_times; doublefactor=10)
    else
        dt_arr, t1_t2_pair_array = [1, 2], [zeros(Int, 2,2)]
    end
    s = SingleComponentSimulation(N, Ndims, r, v, F, D, saved_at_times*dt, box_sizes, dt_arr, t1_t2_pair_array, filename)
    calculate_forces!(s, forcestype)
    return s
end

function read_continuously_hard_sphere_simulation(filename; original=false, velocities=false, forcestype=false, time_origins="quasilog")
    println("Reading data file")
    f = h5open(filename)
    saved_at_times = sort(parse.(Int64, keys(f["positions"])))
    Ndims, N = size(read(f["positions"][string(saved_at_times[1])]))
    
    box_size = read(HDF5.attributes(f)["box_size"])
    dt = float(read(HDF5.attributes(f)["Δt"]))
    dt = ifelse(dt == 0, 1.0, dt) 
    m = 0.0
    try
        m += read(HDF5.attributes(f)["m"])
    catch
        m += 1.0
    end
    kBT = float(read(HDF5.attributes(f)["kBT"]))


    r = zeros(Ndims, N, length(saved_at_times))
    if velocities
         v = zeros(Ndims, N, length(saved_at_times))
    else
         v = zeros(1,1,1)
    end
    if forcestype != false
         F = zeros(Ndims, N, length(saved_at_times))
    else
         F = zeros(1,1,1)
    end
    D = zeros(N, length(saved_at_times))
    D = zeros(N)
    D[:] .= read(f["diameters"]["diameters"])
    N_written = 0
    for t in saved_at_times
        N_written += 1
        r[:, :, N_written] .= read(f["positions"][string(t)])
        if velocities
            v[:, :, N_written] .= read(f["velocities"][string(t)])
        end
    end

    close(f)
    box_sizes = [box_size for i = 1:Ndims]
    if original
        r = find_original_trajectories(r, box_sizes)
    end


    if time_origins == "quasilog"
        dt_arr, t1_t2_pair_array = find_allowed_t1_t2_pair_array_quasilog(saved_at_times; doublefactor=10)
    elseif typeof(time_origins) == Int
        dt_arr, t1_t2_pair_array =  find_allowed_t1_t2_pair_array_log_multstarts(saved_at_times, time_origins)
    else
        error("Specify time origins")
    end
    s = SingleComponentSimulation(N, Ndims, r, v, F, D, saved_at_times*dt, box_sizes, dt_arr, t1_t2_pair_array, filename)
    calculate_forces!(s, forcestype)
    return s
end


function reshape_data(r::Array{Array{Float64,2},1})
    N_timesteps = length(r)
    N, Ndim = size(r[1])    
    rnew = zeros(Ndim, N, N_timesteps)
    for t = 1:N_timesteps
        for particle = 1:N
            for dim = 1:Ndim
                rnew[dim, particle, t] = r[t][particle, dim]
            end
        end
    end
    return rnew
end

function separate_trajectories(r, type_list)
    N_species = length(unique(type_list))
    Ndim, N, N_timesteps = size(r)
    @assert minimum(type_list) == 1
    @assert maximum(type_list) == N_species

    N_particles_per_species = zeros(Int, N_species)
    for type in type_list
        N_particles_per_species[type] += 1
    end
    rvec = [zeros(Ndim, N_particles, N_timesteps) for N_particles in N_particles_per_species]
    particles_done = zeros(Int, N_species)
    for particle = 1:N
        species = type_list[particle]
        particles_done[species] += 1
        for timestep = 1:N_timesteps
            for dim = 1:Ndim
                rvec[species][dim, particles_done[species], timestep] = r[dim, particle, timestep]
            end
        end

    end
    return rvec
end

function remap_positions!(r::Array{Float64,3}, box_sizes)
    N_timesteps = length(r)
    Ndim, N, N_timesteps = size(r)
    for t = 1:N_timesteps
        for particle = 1:N
            for dim = 1:Ndim
                box_size = box_sizes[dim]
                r[dim, particle, t] -= floor(r[dim, particle, t]/box_size)*box_size
            end
        end
    end
end


function find_original_trajectories(r, box_sizes)
    Ndim, N, N_timesteps = size(r)  
    rr = deepcopy(r)
    for particle = 1:N
        for dim = 1:Ndim
            box_size = box_sizes[dim]
            for t = 1:N_timesteps-1
                if rr[dim, particle, t+1] - rr[dim, particle, t] > box_size/2
                    for t2 = t+1:N_timesteps
                        rr[dim, particle, t2] = rr[dim, particle, t2] - box_size
                    end
                elseif rr[dim, particle, t+1] - rr[dim, particle, t] < -box_size/2
                    for t2 = t+1:N_timesteps
                        rr[dim, particle, t2] =rr[dim, particle, t2] + box_size
                    end                
                end
            end
        end
    end
    return rr
end

function find_quasilog_time_array(maxsteps; doublefactor=10)
    save_array = Int64[]
    t = 0
    dt = 1
    while t <= maxsteps
        if !(t % (10*dt) == 0) || t == 0 
            push!(save_array, t)
        end
        t += dt
        if t == dt*doublefactor
            dt *= 10
        end
    end
    return save_array
end

function find_allowed_t1_t2_pair_array_quasilog(t_array; doublefactor=150)
    maxt = t_array[end]-t_array[1]
    dt_array = find_quasilog_time_array(maxt; doublefactor=doublefactor)
    t1_t2_pair_array = Vector{Array{Int64, 2}}()
    for dt in dt_array
        tstart_arr = zeros(Int64, 0, 2)
        for (t1idx, tstart) in enumerate(t_array)
            t2indx = findfirst(isequal(tstart+dt), t_array)
            if !isnothing(t2indx)
                tstart_arr = cat(tstart_arr, [t1idx t2indx], dims=1)
            end
        end
        push!(t1_t2_pair_array, tstart_arr)
    end
    return dt_array, t1_t2_pair_array
end

function find_log_time_array_multiple_starts(log_factor, N_starts, N_max)
    start_times = 0:(N_max÷N_starts):N_max
    when_to_save = Int[collect(start_times)...]
    for i_start in start_times
        t = 1
        while t <= N_max
            push!(when_to_save, t+i_start)
            t *= log_factor
            t = ceil(Int, t)
        end
    end
    push!(when_to_save, N_max)
    return sort(unique(when_to_save[when_to_save .<= N_max]))
end


function find_allowed_t1_t2_pair_array_log_multstarts(t_array, N_starts)
    dt = t_array[2] - t_array[1]
    t_integer_array = round.(Int, t_array/dt)
    maxt = t_integer_array[end]

    dt_array = find_log_time_array_multiple_starts(1.3, 1, maxt)
    @assert all(dt in  t_integer_array for dt in dt_array)

    t1_t2_pair_array = Vector{Array{Int64, 2}}()
    for dt in dt_array
        tstart_arr = Vector{Vector{Int64}}()
        for t1 in 0:(maxt÷N_starts):maxt
            t2 = t1 + dt
            if t2 > maxt
                break
            end
            @assert t2 in t_integer_array
            @assert t1 in t_integer_array
            it1 = findfirst(isequal(t1), t_integer_array)
            it2 = findfirst(isequal(t2), t_integer_array)
            push!(tstart_arr, [it1, it2])
        end
        push!(t1_t2_pair_array, stack(tstart_arr)')
    end
    return dt_array, t1_t2_pair_array
end



calculate_forces!(s, forcestype::Bool) = forcestype ? error("Specify force type") : nothing