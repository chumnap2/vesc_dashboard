using SerialPorts
using Printf

# --- CONFIG ---
const port_name = "/dev/ttyACM0"
const baudrate = 115200

# Open serial port
println("Opening serial port: $port_name at $baudrate baud...")
vesc = SerialPort(port_name, baudrate)
println("Serial port opened. Listening for 1 packet...")

# --- HELPER FUNCTIONS ---

# Read a full VESC packet (blocking)
function read_vesc_packet(port::SerialPort)
    packet = UInt8[]
    while true
        if bytesavailable(port) > 0
            b = read(port, UInt8)
            push!(packet, b)
            # End-of-packet byte 0x03
            if b == 0x03 && length(packet) > 5
                return packet
            end
        end
    end
end

# Send poll command
function poll_vesc(vesc::SerialPort)
    send_bytes = UInt8[0x02, 0x01, 0x03]  # Simple COMM_GET_VALUES (adjust if needed)
    write(vesc, send_bytes)
end

# --- MAIN ---
poll_vesc(vesc)
packet = read_vesc_packet(vesc)
println("Packet received (length $(length(packet)) bytes):")
println(join([@sprintf("%02X", b) for b in packet], " "))
