using PyCall
using Base.Threads: @spawn, sleep

# -------------------------
# 1️⃣ Initialize Python and VESC
# -------------------------
py"""
import serial
import time

ser = serial.Serial('/dev/ttyACM0', 115200, timeout=0.1)

def send_rpm(rpm):
    ser.write(f"{rpm}\n".encode())

# Polling functions
def read_rpm():
    ser.write(b"get_rpm\n")  # Replace with your VESC firmware command
    line = ser.readline().decode().strip()
    return line

def read_pos():
    ser.write(b"get_pos\n")  # Replace with your VESC firmware command
    line = ser.readline().decode().strip()
    return line
"""

send_rpm = py"send_rpm"
read_rpm = py"read_rpm"
read_pos = py"read_pos"

println("🔌 Connected to VESC on /dev/ttyACM0 at 115200 baud")
println("Ctrl+C to exit.\n")

# -------------------------
# 2️⃣ Shared variables
# -------------------------
const GLOBAL_RPM = Ref{Int}(0)
const GLOBAL_TELEMETRY = Ref{String}("No data yet")
const RECENT_RPMS = Ref{Vector{Int}}(fill(0, 50))
const RECENT_POS = Ref{Vector{Float64}}(fill(0.0, 50))
const MAX_GRAPH_HEIGHT = 10

# -------------------------
# 3️⃣ Polling telemetry loop
# -------------------------
@spawn begin
    while true
        line_rpm = read_rpm()
        line_pos = read_pos()

        if !isempty(line_rpm) && !isempty(line_pos)
            GLOBAL_TELEMETRY[] = "RPM: $line_rpm Pos: $line_pos"
            push!(RECENT_RPMS[], parse(Int, line_rpm))
            push!(RECENT_POS[], parse(Float64, line_pos))

            if length(RECENT_RPMS[]) > 50
                popfirst!(RECENT_RPMS[])
            end
            if length(RECENT_POS[]) > 50
                popfirst!(RECENT_POS[])
            end
        end
        sleep(0.05)  # ~20 Hz
    end
end

# -------------------------
# 4️⃣ Display loop
# -------------------------
@spawn begin
    while true
        print("\033[H\033[2J")  # clear screen
        println("🔌 VESC Mini Telemetry Dashboard (Polling Mode)")
        println("Current Telemetry: ", GLOBAL_TELEMETRY[])
        println("Target RPM: ", GLOBAL_RPM[])
        current_rpm = isempty(RECENT_RPMS[]) ? 0 : RECENT_RPMS[][end]
        current_pos = isempty(RECENT_POS[]) ? 0.0 : RECENT_POS[][end]
        println("Current RPM: ", current_rpm)
        println("Motor Position: ", round(current_pos,digits=2))

        # Combined ASCII graph
        graph_width = length(RECENT_RPMS[])
        max_rpm = maximum(maximum(RECENT_RPMS[],1),1)
        max_pos = maximum(maximum(RECENT_POS[],1),1.0)
        heights_rpm = [Int(clamp(r / max_rpm * MAX_GRAPH_HEIGHT,0,MAX_GRAPH_HEIGHT)) for r in RECENT_RPMS[]]
        heights_pos = [Int(clamp(p / max_pos * MAX_GRAPH_HEIGHT,0,MAX_GRAPH_HEIGHT)) for p in RECENT_POS[]]

        println("\nCombined RPM (▇) & Position (▒) Graph:")
        for level in MAX_GRAPH_HEIGHT:-1:1
            for i in 1:graph_width
                if heights_rpm[i] >= level
                    print("▇")
                elseif heights_pos[i] >= level
                    print("▒")
                else
                    print(" ")
                end
            end
            println()
        end
        println("-"^graph_width)

        println("\nType new RPM and press Enter:")
        flush(stdout)
        sleep(0.05)
    end
end

# -------------------------
# 5️⃣ RPM input loop
# -------------------------
while true
    print("> ")
    flush(stdout)
    rpm_input = readline()
    rpm = try
        parse(Int, rpm_input)
    catch
        println("⚠️ Invalid input. Enter an integer RPM.")
        continue
    end
    GLOBAL_RPM[] = rpm
    send_rpm(rpm)
end
