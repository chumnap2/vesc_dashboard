using SerialPorts
using Printf
using Dates
#using Threads
import .Threads

# -----------------------------
# Configuration
# -----------------------------
baudrate = 115200
update_interval = 0.2   # seconds between telemetry updates
max_rpm = 5000
max_duty = 1.0

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
    rpm = clamp(rpm, -max_rpm, max_rpm)
    write(sp, "RPM:$rpm\n")
end

function send_duty(sp, duty)
    duty = clamp(duty, -max_duty, max_duty)
    write(sp, "DUTY:$duty\n")
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
# Start serial + telemetry loop
# -----------------------------
sp = connect_vesc()
println("Starting terminal dashboard... Ctrl+C to stop")
println("Type commands like:  rpm 2000   or   duty 0.3\n")

telemetry_data = Ref((0.0, 0.0, NaN, NaN))
running = Ref(true)

# telemetry thread
Threads.@spawn begin
    start_time = time()
    while running[]
        try
            t = read_telemetry(sp)
            if t !== nothing
                telemetry_data[] = t
                rpm, duty, volt, temp = t
                elapsed = time() - start_time
                @printf "\r[%.1fs] RPM=%7.1f | Duty=%5.2f | Volt=%6.2f | Temp=%5.1f °C " elapsed rpm duty volt temp
                flush(stdout)
            end
        catch
            println("\n[ERROR] Serial read failed — reconnecting...")
            try close(sp) catch end
            sp = connect_vesc()
        end
        sleep(update_interval)
    end
end

# -----------------------------
# Command input loop
# -----------------------------
try
    while true
        print("\n> "); flush(stdout)
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
        elseif cmd in ["exit", "quit", "q"]
            println("Stopping dashboard...")
            running[] = false
            break
        else
            println("Unknown command. Try: rpm <value>, duty <value>, or quit")
        end
    end
catch e
    println("\nStopping dashboard due to error: $e")
finally
    running[] = false
    try CSV.write("vesc_log.csv", df) catch end
    try close(sp) catch end
end
