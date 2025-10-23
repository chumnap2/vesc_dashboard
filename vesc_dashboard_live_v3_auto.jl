using GLMakie
using Observables
using CSV, DataFrames, Dates
using SerialPorts
using Printf
using Statistics

# -----------------------------
# Configuration
# -----------------------------
baudrate = 115200
update_interval = 0.1
log_file = "vesc_telemetry_log.csv"
window_size = 200
max_rpm = 5000
max_duty = 1.0

# -----------------------------
# Connect VESC
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
            println("[WARN] VESC not found — retrying in 2s")
            sleep(2)
        end
    end
end

global sp = connect_vesc()

# -----------------------------
# Telemetry helpers
# -----------------------------
function read_telemetry(sp)
    if bytesavailable(sp) == 0 return nothing end
    line = strip(readline(sp; keep=true))
    # Updated regex for extra telemetry: RPM, POS, DUTY, CURRENT, VOLTAGE, TEMP
    m = match(r"RPM[:=]\s*([-\d.]+).*POS[:=]\s*([-\d.]+).*DUTY[:=]\s*([-\d.]+).*CURR[:=]\s*([-\d.]+).*VOLT[:=]\s*([-\d.]+).*TEMP[:=]\s*([-\d.]+)", line)
    if m !== nothing
        rpm     = parse(Float64, m.captures[1])
        pos     = parse(Float64, m.captures[2])
        duty    = parse(Float64, m.captures[3])
        current = parse(Float64, m.captures[4])
        voltage = parse(Float64, m.captures[5])
        temp    = parse(Float64, m.captures[6])
        return rpm, pos, duty, current, voltage, temp
    end
    return nothing
end

function send_rpm(sp, rpm)
    write(sp, "RPM:$(clamp(rpm,-max_rpm,max_rpm))\n")
end

function send_duty(sp, duty)
    write(sp, "DUTY:$(clamp(duty,-max_duty,max_duty))\n")
end

# -----------------------------
# Data
# -----------------------------
df = DataFrame(
    Timestamp=String[], RPM=Float64[], Duty=Float64[], Position=Float64[],
    Current=Float64[], Voltage=Float64[], Temp=Float64[]
)

timestamps = Observable(Float64[])
rpm_values  = Observable(Float64[])
duty_values = Observable(Float64[])
pos_values  = Observable(Float64[])
current_values = Observable(Float64[])
voltage_values = Observable(Float64[])
temp_values    = Observable(Float64[])

# -----------------------------
# Makie dashboard
# -----------------------------
fig = Figure(size=(1400,700), fontsize=14)

# Left column: plots
ax_rpm  = Axis(fig[1,1], xlabel="Time (s)", ylabel="RPM", title="RPM")
ax_duty = Axis(fig[2,1], xlabel="Time (s)", ylabel="Duty", title="Duty")
ax_pos  = Axis(fig[3,1], xlabel="Time (s)", ylabel="Position (°)", title="Position")
ax_curr = Axis(fig[4,1], xlabel="Time (s)", ylabel="Current (A)", title="Motor Current")
ax_volt = Axis(fig[5,1], xlabel="Time (s)", ylabel="Voltage (V)", title="Input Voltage")
ax_temp = Axis(fig[6,1], xlabel="Time (s)", ylabel="Temp (°C)", title="Motor Temp")

lines!(ax_rpm, timestamps, rpm_values, color=:blue)
lines!(ax_duty, timestamps, duty_values, color=:green)
lines!(ax_pos, timestamps, pos_values, color=:red)
lines!(ax_curr, timestamps, current_values, color=:orange)
lines!(ax_volt, timestamps, voltage_values, color=:purple)
lines!(ax_temp, timestamps, temp_values, color=:brown)

# Right column: sliders + numeric readouts
Label(fig[1,2], "Set RPM")
slider_rpm  = Slider(fig[2,2], range=-max_rpm:max_rpm, startvalue=0)
label_rpm_value = Label(fig[2,3], string(slider_rpm.value[]))

Label(fig[3,2], "Set Duty")
slider_duty = Slider(fig[4,2], range=-max_duty:max_duty, startvalue=0.0)
label_duty_value = Label(fig[4,3], string(slider_duty.value[]))

# Update numeric labels whenever sliders move
on(slider_rpm.value) do val
    label_rpm_value.text = @sprintf("%.0f", val)
end

on(slider_duty.value) do val
    label_duty_value.text = @sprintf("%.2f", val)
end

# Display figure safely
try
    display(fig)
catch e
    isa(e, InterruptException) && nothing
end

start_time = time()

# -----------------------------
# Main loop
# -----------------------------
try
    println("Starting Stage 5h full telemetry dashboard... Ctrl+C to stop")
    while true
        elapsed = time() - start_time
        telemetry = nothing
        try
            telemetry = read_telemetry(sp)
        catch
            println("[ERROR] Serial read failed — reconnecting...")
            close(sp)
            global sp = connect_vesc()
            continue
        end

        if telemetry !== nothing
            rpm, pos, duty, curr, volt, temp = telemetry

            # Rolling window
            push!(timestamps[], elapsed)
            push!(rpm_values[], rpm)
            push!(duty_values[], duty)
            push!(pos_values[], pos)
            push!(current_values[], curr)
            push!(voltage_values[], volt)
            push!(temp_values[], temp)

            if length(timestamps[]) > window_size
                timestamps[]   = timestamps[][end-window_size+1:end]
                rpm_values[]   = rpm_values[][end-window_size+1:end]
                duty_values[]  = duty_values[][end-window_size+1:end]
                pos_values[]   = pos_values[][end-window_size+1:end]
                current_values[]= current_values[][end-window_size+1:end]
                voltage_values[]= voltage_values[][end-window_size+1:end]
                temp_values[]  = temp_values[][end-window_size+1:end]
            end

            # Optional smoothing for RPM
            smoothed_rpm = [mean(rpm_values[][max(1,i-4):i]) for i in 1:length(rpm_values[])]
            rpm_values[] = smoothed_rpm

            # Log telemetry
            push!(df, (string(Dates.now()), rpm, duty, pos, curr, volt, temp))
            @printf "[TELEM] t=%.1fs RPM=%.1f Duty=%.2f Pos=%.1f° Curr=%.2fA Volt=%.2fV Temp=%.1f°C\n" elapsed rpm duty pos curr volt temp
        end

        # Automatic control: send current slider values
        send_rpm(sp, slider_rpm.value[])
        send_duty(sp, slider_duty.value[])

        sleep(update_interval)
    end
catch e
    if isa(e, InterruptException)
        println("\nDashboard stopped by user — shutting down...")
    else
        println("Error in Stage 5h dashboard: $e")
    end
finally
    CSV.write(log_file, df)
    close(sp)
end
