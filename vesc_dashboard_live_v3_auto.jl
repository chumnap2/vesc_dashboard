### === Stage 5c: Auto-Port + Safe Reconnect ===
using SerialPorts
using Plots
using CSV
using DataFrames
using Dates
using Printf

# ---------------------------------------------
# Configuration
# ---------------------------------------------
baudrate = 115200
update_interval = 0.1
log_file = "vesc_telemetry_log.csv"
max_rpm = 5000
max_duty = 1.0

# ---------------------------------------------
# Auto-port finder
# ---------------------------------------------
function find_vesc_port()
    ports = filter(p -> occursin("ttyACM", p), readdir("/dev"; join=true))
    isempty(ports) && error("No /dev/ttyACM* device found — plug in VESC.")
    return first(sort(ports))
end

# ---------------------------------------------
# Auto-reconnect handler
# ---------------------------------------------
function connect_vesc()
    while true
        try
            port_name = find_vesc_port()
            sp = SerialPort(port_name, baudrate)
            println("Connected to $port_name at $baudrate bps")
            return sp
        catch e
            println("[WARN] VESC not found or busy — retrying in 2 s...")
            sleep(2)
        end
    end
end

# ---------------------------------------------
# Command helpers
# ---------------------------------------------
function send_rpm(sp, rpm)
    rpm = clamp(rpm, -max_rpm, max_rpm)
    write(sp, "RPM:$rpm\n")
    println("[Sent RPM] $rpm")
end

function send_duty(sp, duty)
    duty = clamp(duty, -max_duty, max_duty)
    write(sp, "DUTY:$duty\n")
    println("[Sent DutyCycle] $duty")
end

# ---------------------------------------------
# Telemetry parser
# Works for lines like:  "RPM:1200 POS:34.5 DUTY:0.4"
# ---------------------------------------------
function read_telemetry(sp)
    if bytesavailable(sp) == 0
        return nothing
    end
    line = strip(readline(sp; keep=true))
    m = match(r"RPM[:=]\s*([-\d.]+).*POS[:=]\s*([-\d.]+).*DUTY[:=]\s*([-\d.]+)", line)
    if m !== nothing
        rpm  = parse(Float64, m.captures[1])
        pos  = parse(Float64, m.captures[2])
        duty = parse(Float64, m.captures[3])
        return rpm, pos, duty
    end
    return nothing
end

# ---------------------------------------------
# Initialize
# ---------------------------------------------
println("=== VESC Live Dashboard v3 Auto (Stage 5c) ===")
sp = connect_vesc()

function run_dashboard()
    println("=== VESC Live Dashboard v3 Auto (Stage 5c) ===")
    sp = connect_vesc()

    df = DataFrame(Timestamp=String[], RPM=Float64[], Duty=Float64[], Position=Float64[])
    plt = plot(title="VESC Telemetry", xlabel="Time (s)", ylabel="RPM", legend=false)
    timestamps = Float64[]
    rpm_values = Float64[]
    start_time = time()

    try
        println("Starting live telemetry loop... (Ctrl+C to stop)")
        while true
            elapsed = time() - start_time
            telemetry = nothing
            try
                telemetry = read_telemetry(sp)
            catch e
                println("[ERROR] Serial read failed — reconnecting...")
                close(sp)
                sp = connect_vesc()
                continue
            end

            if telemetry !== nothing
                rpm, pos, duty = telemetry
                push!(df, (string(Dates.now()), rpm, duty, pos))
                push!(timestamps, elapsed)
                push!(rpm_values, rpm)
                plot!(plt, timestamps, rpm_values; color=:blue)
                display(plt)
                @printf "[TELEM] t=%.1fs RPM=%.1f Duty=%.2f Pos=%.1f°\n" elapsed rpm duty pos
            end

            if floor(Int, elapsed) % 5 == 0
                print("> Enter RPM (or Enter to skip): ")
                rpm_input = readline(stdin)
                if !isempty(rpm_input)
                    send_rpm(sp, parse(Float64, rpm_input))
                end
                print("> Enter Duty [-1..1] (or Enter to skip): ")
                duty_input = readline(stdin)
                if !isempty(duty_input)
                    send_duty(sp, parse(Float64, duty_input))
                end
            end

            sleep(update_interval)
        end
    catch e
        println("Stopping dashboard: $e")
    finally
        println("Saving log to $log_file ...")
        CSV.write(log_file, df)
        close(sp)
    end
end

# Run safely
run_dashboard()

