### vesc_dashboard_live_v3.jl
using SerialPorts
using Plots
using CSV
using DataFrames
using Dates
using Printf

# -----------------------------
# Configuration
# -----------------------------
port_name = "/dev/ttyACM1"
baudrate = 115200
update_interval = 0.1  # seconds
log_file = "vesc_telemetry_log.csv"

# Max limits
max_rpm = 5000
max_duty = 1.0

# -----------------------------
# Connect to VESC
# -----------------------------
println("=== VESC Live Dashboard v3 Safe ===")
sp = SerialPort(port_name, baudrate)
println("Connected to $port_name at $baudrate bps")

# -----------------------------
# Telemetry logging setup
# -----------------------------
df = DataFrame(Timestamp=String[], RPM=Float64[], Duty=Float64[], Position=Float64[])

# -----------------------------
# Live plot setup
# -----------------------------
plt = plot(title="VESC Telemetry", xlabel="Time (s)", ylabel="RPM", legend=false)
timestamps = Float64[]
rpm_values = Float64[]

# -----------------------------
# Helper functions
# -----------------------------
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

# -----------------------------
# Improved telemetry reader (Stage 5b)
# -----------------------------
function read_telemetry(sp)
    # Works with messages like:
    #   RPM:1234.5 POS:67.8 DUTY:0.45 CURR:2.3 VOLT:50.1
    if bytesavailable(sp) == 0
        return nothing
    end
    line = strip(readline(sp; keep=true))
    # println("[DEBUG] ", line)  # uncomment if you want to inspect raw serial lines

    m = match(r"RPM[:=]\s*([-\d.]+).*POS[:=]\s*([-\d.]+).*DUTY[:=]\s*([-\d.]+)", line)
    if m !== nothing
        rpm  = parse(Float64, m.captures[1])
        pos  = parse(Float64, m.captures[2])
        duty = parse(Float64, m.captures[3])
        return rpm, pos, duty
    else
        return nothing
    end
end

# -----------------------------
# Main loop (non-blocking telemetry + plot)
# -----------------------------
println("Starting live telemetry loop...  (Ctrl+C to stop)")
start_time = time()

try
    while true
        elapsed = time() - start_time

        # Non-blocking telemetry read
        telemetry = read_telemetry(sp)
        if telemetry !== nothing
            rpm, pos, duty = telemetry

            # Log and update arrays
            push!(df, (string(Dates.now()), rpm, duty, pos))
            push!(timestamps, elapsed)
            push!(rpm_values, rpm)

            # Live plot update
            plot!(plt, timestamps, rpm_values; color=:blue, legend=false)
            display(plt)

            # Console feedback
            @printf "[TELEM] t=%.1fs RPM=%.1f Duty=%.2f Pos=%.1f°\n" elapsed rpm duty pos
        end

        # Optional user control every few seconds
        if floor(Int, elapsed) % 5 == 0  # prompt roughly every 5 s
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

