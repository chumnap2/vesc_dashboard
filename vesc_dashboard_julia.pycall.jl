using PyCall
using Printf

# --- Ensure Python venv is visible ---
py"""
import sys
sys.path.insert(0, "/home/chumnap/fprime-venv/lib/python3.12/site-packages")
"""

# --- Import VESC class ---
VESC = pyimport("pyvesc_fix.VESC.VESC").VESC

const port_name = "/dev/ttyACM0"
const baudrates = [115200, 57600]

# --- Initialize VESC ---
global vesc = nothing

for br in baudrates
    try
        println("Trying baudrate: $br ... ")
        global vesc = VESC(port_name, br)
        println("✅ Success")
        break
    catch e
        println("❌ Failed: ", e)
    end
end

if vesc === nothing
    error("Could not initialize VESC on any baudrate")
end

println("🚀 VESC Dashboard ready\nPolling every 0.5s... Ctrl+C to stop.\n")

# --- Telemetry polling loop ---
while true
    try
        telemetry = vesc.get_values()  # returns Python object with VESC telemetry

        # Access some common telemetry values
        rpm      = telemetry.rpm
        v_in     = telemetry.v_in
        motor_i  = telemetry.avg_motor_current
        temp_mot = telemetry.temp_motor
        temp_mos = telemetry.temp_mos

        @printf("RPM: %7.0f | Vin: %5.1f V | Motor I: %5.1f A | T_motor: %5.1f °C | T_MOS: %5.1f °C\n",
                rpm, v_in, motor_i, temp_mot, temp_mos)
    catch e
        println("⚠️ Error reading telemetry: ", e)
    end
    sleep(0.5)
end
