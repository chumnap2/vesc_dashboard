#################################################
# vesc_dashboard_live_safe.jl
# VESC Live Dashboard for Julia + pyvesc 2.x
# Safe input + real-time telemetry
#################################################

using PyCall
using Dates

# --- VESC connection settings ---
port = "/dev/ttyACM0"
baud = 115200

# --- Motor settings ---
max_rpm = 5000        # adjust for your motor
max_duty = 1.0        # duty cycle [-1.0, 1.0]

# --- Import Python modules and connect ---
py"""
import pyvesc
import serial

ser = serial.Serial(port=$port, baudrate=$baud)

# --- Helper Python functions ---
def send_rpm_py(val, ser):
    msg = pyvesc.SetRPM(int(val))
    ser.write(pyvesc.encode(msg))

def send_duty_py(val, ser):
    msg = pyvesc.SetDuty(float(val))
    ser.write(pyvesc.encode(msg))

def read_telemetry(ser):
    if ser.in_waiting > 0:
        raw = ser.read(ser.in_waiting)
        msg = pyvesc.decode(raw)
        if msg is not None:
            return dict(msg.__dict__)
    return None
"""

# --- Bind Python functions ---
send_rpm_py = py"send_rpm_py"
send_duty_py = py"send_duty_py"
read_telemetry = py"read_telemetry"

println("=== VESC Live Dashboard (pyvesc 2.x) ===")
println("Connected to $port at $baud bps")
println("Press Ctrl+C to stop.")

# --- Julia helpers ---
function send_rpm(rpm::Int)
    rpm_val = clamp(rpm, -max_rpm, max_rpm)
    send_rpm_py(rpm_val, py"ser")
    println("Sent RPM: $rpm_val")
end

function send_duty(duty::Float64)
    duty_val = clamp(duty, -max_duty, max_duty)
    send_duty_py(duty_val, py"ser")
    println("Sent Duty: $(round(duty_val, digits=3))")
end

# --- Safe input parsing ---
function try_parse_int(s::String)
    try
        return parse(Int, strip(s))
    catch
        return nothing
    end
end

function try_parse_float(s::String)
    try
        return parse(Float64, strip(s))
    catch
        return nothing
    end
end

# --- Main loop ---
while true
    try
        # --- User input ---
        print("Enter RPM (or Enter to skip): ")
        rpm_input = readline()
        rpm = try_parse_int(rpm_input)
        if rpm !== nothing
            send_rpm(rpm)
        else
            println("[INFO] RPM skipped or invalid input")
        end

        print("Enter Duty [-1.0..1.0] (or Enter to skip): ")
        duty_input = readline()
        duty = try_parse_float(duty_input)
        if duty !== nothing
            send_duty(duty)
        else
            println("[INFO] Duty skipped or invalid input")
        end

        # --- Read telemetry ---
        telemetry = read_telemetry(py"ser")
        if telemetry !== nothing
            println("---- TELEMETRY ----")
            for (k,v) in telemetry
                println(k, ": ", v)
            end
        else
            println("No telemetry available...")
        end

    catch e
        println("[ERROR] ", e)
    end
end
