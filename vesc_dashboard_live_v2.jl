#################################################
# vesc_dashboard_live_v3_safe.jl
# VESC Live Dashboard for Julia + pyvesc 2.x
# Fully safe telemetry (firmware-agnostic) + RPM/Duty
#################################################

using PyCall
using Dates

# --- VESC connection settings ---
port = "/dev/ttyACM0"
baud = 115200

# --- Motor limits ---
max_rpm = 5000
max_duty = 1.0

# --- Python setup ---
py"""
from pyvesc import pyvesc, messages
import serial

ser = serial.Serial(port=$port, baudrate=$baud)

def send_rpm_py(val):
    msg = messages.SetRPM(int(val), reply=False)
    ser.write(pyvesc.encode(msg))

def send_duty_py(val):
    duty_int = int(val * 100000)
    msg = messages.SetDutyCycle(duty_int, reply=False)
    ser.write(pyvesc.encode(msg))

def read_telemetry_safe():
    if ser.in_waiting > 0:
        raw = ser.read(ser.in_waiting)
        try:
            msg = pyvesc.decode(raw)
            if msg is not None:
                d = {}
                for k in getattr(msg, "__dict__", {}):
                    try:
                        d[k] = getattr(msg, k)
                    except AttributeError:
                        d[k] = "N/A"
                return d
        except Exception:
            return None
    return None
"""

# --- Bind Python functions ---
send_rpm_py = py"send_rpm_py"
send_duty_py = py"send_duty_py"
read_telemetry = py"read_telemetry_safe"

println("=== VESC Live Dashboard v3 Safe (pyvesc 2.x) ===")
println("Connected to $port at $baud bps")
println("Press Ctrl+C to stop.")

# --- Helper functions ---
try_parse_int(s::String) = try parse(Int, strip(s)) catch; nothing end
try_parse_float(s::String) = try parse(Float64, strip(s)) catch; nothing end

function send_rpm(rpm::Int)
    rpm_val = clamp(rpm, -max_rpm, max_rpm)
    send_rpm_py(rpm_val)
    println("[Sent RPM] $rpm_val")
end

function send_duty(duty::Float64)
    duty_val = clamp(duty, -max_duty, max_duty)
    send_duty_py(duty_val)
    println("[Sent DutyCycle] $(round(duty_val, digits=3))")
end

# --- Telemetry loop (async, safe) ---
@async begin
    while true
        try
            telem = read_telemetry()
            if telem !== nothing
                println("\n---- TELEMETRY @ ", Dates.now(), " ----")
                for (k,v) in telem
                    println(k, ": ", v)
                end
                print("\n> ")  # keep prompt visible
            end
            sleep(0.5)   # refresh interval
        catch e
            println("[Telemetry ERROR] ", e)
            sleep(1.0)
        end
    end
end

# --- Main interactive loop ---
while true
    try
        print("> Enter RPM (or Enter to skip): ")
        rpm_input = readline()
        rpm_val = try_parse_int(rpm_input)
        if rpm_val !== nothing
            send_rpm(rpm_val)
        end

        print("> Enter Duty [-1.0..1.0] (or Enter to skip): ")
        duty_input = readline()
        duty_val = try_parse_float(duty_input)
        if duty_val !== nothing
            send_duty(duty_val)
        end
    catch e
        println("[Input ERROR] ", e)
    end
end
