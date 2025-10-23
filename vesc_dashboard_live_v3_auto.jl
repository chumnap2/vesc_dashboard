using SerialPorts
using Printf
using Dates
using CSV
# Tables.jl is not needed; CSV works directly with NamedTuples

# -----------------------------
# Configuration
# -----------------------------
baudrate = 115200
update_interval = 0.2   # seconds
max_rpm = 5000
max_duty = 1.0
log_file = "vesc_telemetry_log.csv"

# -----------------------------
# Auto-port + reconnect
# -----------------------------
function find_vesc_port()
    ports = filter(p -> occursin("ttyACM", p), readdir("/dev"; join=true))
    isempty(ports) && error("No /dev/ttyACM* device found — plug in VESC.")
    return first(sort(ports))
end

function connect_vesc()
    while true
        try
            port_name = find_vesc_port()
            sp = SerialPort(port_name, baudrate)
            println("Connected to $port_name at $baudrate bps")
            return sp
        catch
            println("[WARN] VESC not found — retrying in 2 s...")
            sleep(2)
        end
    end
end

# -----------------------------
# Command helpers
# -----------------------------
function send_rpm(sp, rpm)
    write(sp, "RPM:$(clamp(rpm, -max_rpm, max_rpm))\n")
end

function send_duty(sp, duty)
    write(sp, "DUTY:$(clamp(duty, -max_duty, max_duty))\n")
end

# -----------------------------
# Telemetry parser
# -----------------------------
function read_telemetry(sp)
    if bytesavailable(sp) == 0
        return nothing
    end
    line = strip(readline(sp; keep=true))
    m = match(r"RPM[:=]\s*([-\d.]+).*DUTY[:=]\s*([-\d.]+).*VOLT[:=]\s*([-\d.]+)?.*TEMP[:=]\s*([-\d.]+)?", line)
    if m !== nothing
        rpm  = parse(Float64, m.captures[1])
        duty = parse(Float64, m.captures[2])
        volt = m.captures[3] === nothing ? NaN : parse(Float64, m.captures[3])
        temp = m.captures[4] === nothing ? NaN : parse(Float64, m.captures[4])
        return rpm, duty, volt, temp
    end
    return nothing
end

# -----------------------------
# Terminal helpers
# -----------------------------
function clear_terminal()
    print("\033[2J\033[H")
end

function print_dashboard(data)
    clear_terminal()
    println("=== VESC Live Telemetry Dashboard (Stage 7) ===")
    println("-----------------------------------------------")
    @printf("RPM:         %8.2f\n", data[:rpm])
    @printf("Duty Cycle:  %8.2f %%\n", data[:duty])
    @printf("Voltage:     %8.2f V\n", data[:voltage])
    @printf("Temperature: %8.2f °C\n", data[:temp])
    println("-----------------------------------------------")
    println("Type commands: rpm <value>  |  duty <value>  |  quit")
end

# -----------------------------
# Main loop
# -----------------------------
sp = connect_vesc()
println("Starting Stage 7 terminal dashboard with CSV logging and safety alerts...")
telemetry_data = Ref((0.0, 0.0, NaN, NaN))
running = Ref(true)

# Storage for CSV
log_buffer = Vector{NamedTuple{(:Timestamp, :RPM, :Duty, :Voltage, :Temp), Tuple{String, Float64, Float64, Float64, Float64}}}()

# Telemetry thread
Threads.@spawn begin
    start_time = time()
    while running[]
        t = read_telemetry(sp)
        if t !== nothing
            rpm, duty, volt, temp = t
            telemetry_data[] = t

            # --- Minimal safety alerts ---
            if volt < 20 || volt > 60
                println("\n[WARNING] Voltage out of safe range: $volt V")
            end
            if temp > 80
                println("\n[WARNING] Temperature too high: $temp °C")
            end
            if abs(duty) > 0.9
                println("\n[WARNING] Duty cycle high: $duty")
            end
            if rpm > 5000
                println("\n[WARNING] RPM exceeds max limit: $rpm")
            end

            # Append to log buffer
            push!(log_buffer, (string(Dates.now()), rpm, duty, volt, temp))
            print_dashboard(Dict(:rpm=>rpm, :duty=>duty, :voltage=>volt, :temp=>temp))
        end
        sleep(update_interval)
    end
end

# Command input loop
try
    while true
        print("> "); flush(stdout)
        input = readline(stdin)
        parts = split(strip(input))
        isempty(parts) && continue
        cmd = lowercase(parts[1])
        if cmd == "rpm" && length(parts) == 2
            send_rpm(sp, parse(Float64, parts[2]))
            println("→ RPM command sent.")
        elseif cmd == "duty" && length(parts) == 2
            send_duty(sp, parse(Float64, parts[2]))
            println("→ Duty command sent.")
        elseif cmd in ["quit", "q"]
            println("Stopping dashboard...")
            running[] = false
            break
        else
            println("Unknown command. Try: rpm <value>, duty <value>, quit")
        end
    end
catch e
    println("\nStopping dashboard due to error: $e")
finally
    running[] = false
    sleep(0.3)  # wait for thread to finish
    try close(sp) catch end
    # Write CSV
    CSV.write(log_file, log_buffer)
    println("Telemetry saved to $log_file")
end
