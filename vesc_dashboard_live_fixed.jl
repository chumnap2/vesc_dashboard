#################################################
# vesc_dashboard_live_fixed.jl
# VESC Live Dashboard for Julia + pyvesc 2.x
# Real-time telemetry + SetRPM / SetDutyCycle
#################################################

using PyCall
using Dates

# --- VESC connection settings ---
port = "/dev/ttyACM0"
baud = 115200

# --- Motor limits ---
max_rpm = 5000
max_duty = 1.0

# --- Python setup for pyvesc 2.x ---
py"""
from pyvesc import pyvesc, messages
import serial

ser = serial.Serial(port=$port, baudrate=$baud)

def send_rpm_py(val):
    msg = messages.SetRPM(int(val), reply=False)
    ser.write(pyvesc.encode(msg))

def send_duty_py(val):
    # convert float [-1.0..1.0] → int [-100000..100000]
    duty_int = int(val * 100000)
    msg = messages.SetDutyCycle(duty_int, reply=False)
    ser.write(pyvesc.encode(msg))

def read_telemetry():
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

println("=== VESC Live Dashboard (pyvesc 2.x messages API) ===")
println("Connected to $port at $baud bps")
println("Press Ctrl+C to stop.")

# --- Main interactive loop ---
while true
    try
        print("> Enter RPM (or Enter to skip): ")
        rpm_input = readline()
        if !isempty(rpm_input)
            rpm_val = clamp(parse(Int, rpm_input), -max_rpm, max_rpm)
            send_rpm_py(rpm_val)
            println("Sent RPM: $rpm_val")
        end

        print("> Enter Duty [-1.0..1.0] (or Enter to skip): ")
        duty_input = readline()
        if !isempty(duty_input)
            duty_val = clamp(parse(Float64, duty_input), -max_duty, max_duty)
            send_duty_py(duty_val)
            println("Sent DutyCycle: $(round(duty_val, digits=3))")
        end

        # --- Telemetry read ---
        telem = read_telemetry()
        if telem !== nothing
            println("---- TELEMETRY ----")
            for (k, v) in telem
                println(k, ": ", v)
            end
        else
            println("[No telemetry data]")
        end

    catch e
        println("[ERROR] ", e)
    end
end
