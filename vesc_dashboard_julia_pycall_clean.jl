############################################################
# VESC Dashboard (Julia + PyCall + PyVESC 1.0.5)
# FINAL VERSION — binary safe, no UnicodeDecodeError
############################################################

using PyCall

println("=== VESC Dashboard (PyVESC 1.0.5) ===")
println("Type new RPM and press Enter, or Ctrl+C to quit.\n")

# --- Import Python modules ---
pyvesc = pyimport("pyvesc")
serial = pyimport("serial")

# --- Define safe Python helper functions (no PyCall byte decoding) ---
py"""
import serial, pyvesc

ser = None

def open_port(port="/dev/ttyACM0", baud=115200, timeout=0.3):
    global ser
    ser = serial.Serial(port, baud, timeout=timeout)
    ser.reset_input_buffer()
    ser.reset_output_buffer()
    return True

def close_port():
    global ser
    if ser:
        ser.close()
        ser = None

def send_rpm(rpm):
    global ser
    if not ser:
        raise Exception("Serial not open")
    pkt = pyvesc.SetRPM(int(rpm))
    encoded = pyvesc.encode(pkt)
    ser.write(encoded)

def read_values_safe():
    global ser
    if not ser:
        return None
    try:
        data = ser.read_all()
        if not data:
            return None
        decoded = pyvesc.decode(data)
        if not decoded:
            return None
        msg = decoded[0]
        if isinstance(msg, pyvesc.GetValues):
            return {
                "rpm": msg.rpm,
                "v_in": msg.v_in,
                "current_motor": msg.current_motor,
                "duty_cycle": msg.duty_cycle,
            }
        return None
    except UnicodeDecodeError:
        # ignore garbled partial packets
        return None
    except Exception as e:
        return {"error": str(e)}
"""

# --- Open serial port ---
try
    py"open_port"("/dev/ttyACM0", 115200)
catch e
    println("ERROR: Cannot open /dev/ttyACM0.")
    rethrow(e)
end

# --- Main loop ---
try
    while true
        print("\nEnter RPM: ")
        rpm_input = readline(stdin)
        rpm_input == "" && continue

        rpm = tryparse(Int, rpm_input)
        rpm === nothing && (println("Invalid RPM."); continue)

        py"send_rpm"(rpm)
        sleep(0.4)

        vals = py"read_values_safe"()
        if vals === nothing
            println("No telemetry or decode error.")
        elseif haskey(vals, "error")
            println("[ERROR] ", vals["error"])
        else
            println("Telemetry:")
            for (k, v) in vals
                println("  $k = $v")
            end
        end
    end
catch e
    println("\nExiting: ", e)
finally
    println("\nClosing serial port...")
    py"close_port"()
end
