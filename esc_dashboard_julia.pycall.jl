using PyCall
using Printf

# -----------------------------
# Import Python modules
# -----------------------------
serial = pyimport("serial")
pyvesc = pyimport("pyvesc_fix")   # <- use pyvesc-fix module
VESC = pyvesc."VESC"              # get the VESC class

# -----------------------------
# Open VESC USB port
# -----------------------------
port_name = "/dev/ttyACM0"
baudrate = 115200

println("Opening serial port: $port_name at $baudrate baud...")
ser = serial.Serial(port_name, baudrate, timeout=1)
vesc = VESC(ser)
println("Serial port opened.\n")

println("🚀 VESC Dashboard (Julia + Python)")
println("Polling every 0.5s... Ctrl+C to stop.\n")

# -----------------------------
# Polling loop
# -----------------------------
try
    while true
        # Get VESC telemetry
        values = vesc[:get_values]()  # call Python method

        # Print key telemetry
        @printf "Voltage: %.2f V | Current: %.2f A | RPM: %.0f | Duty: %.1f%% | Ah: %.2f | Motor Temp: %.1f°C\n" \
                values[:v_in], values[:avg_motor_current], values[:rpm], values[:duty_cycle]*100, values[:amp_hours], values[:t_motor]

        sleep(0.5)
    end
catch e
    println("\nExiting VESC dashboard: ", e)
    ser[:close]()
end
