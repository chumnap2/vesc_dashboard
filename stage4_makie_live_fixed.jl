using GLMakie

# --- Global state ---
global rpm = 0.0
global pos = 0.0

# --- Simulation parameters ---
dt = 0.05
k = 0.1

# --- Create figure and axes ---
fig = Figure(size = (600, 400))
ax1 = Axis(fig[1, 1], xlabel = "Time [s]", ylabel = "RPM")
ax2 = Axis(fig[2, 1], xlabel = "Time [s]", ylabel = "Position [°]")

# Observables for live data
times = Observable(Float64[])
rpm_values = Observable(Float64[])
pos_values = Observable(Float64[])

lines!(ax1, times, rpm_values, color = :red, label = "RPM")
lines!(ax2, times, pos_values, color = :blue, label = "Position")

display(fig)

# --- Async command listener ---
function command_listener()
    while true
        try
            print("Enter new target RPM: ")
            input = readline()
            global rpm
            rpm = parse(Float64, input)
        catch e
            @warn "Invalid input, try again"
        end
    end
end

@async command_listener()

# --- Main simulation loop ---
function run_simulation()
    t = 0.0
    while isopen(fig.scene)
        sleep(dt)
        t += dt

        global rpm, pos
        pos += k * (rpm - pos) * dt

        # Append to observables (triggers live update)
        times[] = push!(times[], t)
        rpm_values[] = push!(rpm_values[], rpm)
        pos_values[] = push!(pos_values[], pos)

        # Optional telemetry
        println("[TELEMETRY] RPM=$(round(rpm, digits=1)) Pos=$(round(pos, digits=2))")

        # Explicit redraw (Makie handles it internally, but helps on WSL)
        if Makie.isinteractive()
            yield()
        else
            sleep(0.01)  # keep loop responsive
        end
    end
end

run_simulation()
