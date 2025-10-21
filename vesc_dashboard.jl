using SerialPorts
using Printf

# ===============================
# CONFIGURATION
# ===============================
const port_name = "/dev/ttyACM0"
const baudrate  = 115200
const poll_interval = 0.5  # seconds

println("Opening serial port: $port_name at $baudrate baud...")
vesc = SerialPort(port_name, baudrate)
println("Serial port opened.")

# ===============================
# CRC16 (Modbus variant)
# ===============================
function crc16(data::Vector{UInt8})
    crc = 0xFFFF
    for byte in data
        crc ⊻= UInt16(byte)
        for _ in 1:8
            if (crc & 1) != 0
                crc = (crc >> 1) ⊻ 0xA001
            else
                crc >>= 1
            end
        end
    end
    return crc
end

# ===============================
# Build COMM_GET_VALUES packet (USB framing)
# ===============================
function build_get_values_packet()
    payload = UInt8[0x04] # COMM_GET_VALUES
    crc_val = crc16(payload)
    crc_bytes = UInt8[crc_val & 0xFF, (crc_val >> 8) & 0xFF]

    start = UInt8(0x02)
    stop  = UInt8(0x03)
    len_high = UInt8(0)
    len_low = UInt8(length(payload))

    packet = UInt8[start, len_high, len_low, payload..., crc_bytes..., stop]
    return packet
end

# ===============================
# Read one USB packet (blocking)
# ===============================
function read_vesc_packet(port::SerialPort; timeout_sec=1.0)
    buffer = UInt8[]
    t_start = time()
    while true
        if bytesavailable(port) > 0
            byte = read(port, UInt8)
            push!(buffer, byte)
            if byte == 0x03 && length(buffer) > 4
                return buffer
            end
        end
        if time() - t_start > timeout_sec
            return UInt8[]
        end
        sleep(0.001)
    end
end

# ===============================
# Print raw packet
# ===============================
function print_packet(data::Vector{UInt8})
    if isempty(data)
        println("⚠️ No data received")
        return
    end
    @printf("RX (%d bytes): ", length(data))
    println(join([@sprintf("%02X", b) for b in data], " "))
end

# ===============================
# MAIN LOOP
# ===============================
println("🚀 VESC USB Dashboard (Polling Mode)")

while true
    packet = build_get_values_packet()
    @printf("TX: "); println(join([@sprintf("%02X", b) for b in packet], " "))
    write(vesc, packet)

    sleep(0.05)  # allow device time to respond

    if bytesavailable(vesc) > 0
        response = read_vesc_packet(vesc)
        print_packet(response)
    else
        println("No response yet...")
    end

    sleep(poll_interval)
end
