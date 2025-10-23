using PyCall

# Import pyvesc and serial
serial = pyimport("serial")
pyvesc = pyimport("pyvesc")
interface = pyvesc.interface

# Serial port configuration
port = "/dev/ttyACM0"  # adjust if needed
baud = 115200

# Open serial port
global ser
try
    ser = serial.Serial(port, baud, timeout=1)
    println("=== VESC Live Dashboard (pyvesc-fix) ===")
    println("Connected to $port at $baud bps")
catch e
    println("[ERROR] Could not open $port: $e")
    exit(1)
end

# Function to safely get telemetry
function get_telemetry()
    try
        vals = interface.GetValues(ser)  # request values
        rpm     = hasproperty(vals, :rpm)      ? vals.rpm      : nothing
        voltage = hasproperty(vals, :v_in)     ? vals.v_in     : nothing
        current = hasproperty(vals, :current)  ? vals.current  : nothing
        duty    = hasproperty(vals, :duty_now) ? vals.duty_now : nothing
        return (rpm=rpm, voltage=voltage, current=current, duty=duty)
    catch e
        return nothing
    end
end

# Main loop
try
    while true
        # Read telemetry
        telem = get_telemetry()
        if telem !== nothing
            println("Telemetry → RPM: $(telem.rpm), V: $(telem.voltage), I: $(telem.current), Duty: $(telem.duty)")
        else
            println("No telemetry available...")
        end

        # Non-blocking input for new RPM
        print("Enter RPM (or press Enter to skip): ")
        rpm_str = readline(stdin)
        if !isempty(rpm_str)
            try
                rpm_val = parse(Int, rpm_str)
                msg = pyvesc.SetRPM(rpm_val)
                pyvesc.encode(msg, ser)  # send message
                println("[INFO] Sent RPM: $rpm_val")
            catch e
                println("[ERROR] Could not send RPM: $e")
            end
        end

        sleep(0.5)  # update interval
    end
catch InterruptException
    println("\nExiting...")
finally
    ser.close()
    println("Serial port closed.")
end
