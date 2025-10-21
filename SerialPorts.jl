using SerialPorts
using Base: stdin
using Printf

# --- CONFIG ---
const port_name = "/dev/ttyACM0"
const baudrate = 115200

# Open serial port
vesc = SerialPort(port_name, baudrate)

# --- GLOBAL VARIABLES ---
global target_rpm = 0

# --- HELPER FUNCTIONS ---
function send_bytes(vesc::SerialPort, bytes::Vector{UInt8})
    write(vesc, bytes)
end

# CRC16 (Modbus)
function crc16(data::Vector{UInt8})
    crc = 0xFFFF
    for byte in data
        crc = crc ⊻ UInt16(byte)
        for _ in 1:8
            if (crc & 0x0001) != 0
                crc = UInt16((crc >> 1) ⊻ 0xA001)
            else
                crc >>= 1
            end
        end
    end
    return crc
end

# Build GET_VALUES packet
function build_get_values_packet()
    cmd = UInt8[0x04]  # COMM_GET_VALUES
    crc_val = crc16(cmd)
    crc_bytes = UInt8[crc_val & 0xFF, (crc_val >> 8) & 0xFF]
    packet = UInt8[0x02, length(cmd), cmd..., crc_bytes..., 0x03]
    return packet
end

# Build SET_RPM packet
function build_set_rpm_packet(rpm::Int)
    payload = UInt8[rpm & 0xFF, (rpm >> 8) & 0xFF]
    cmd = UInt8[0x05] # SET_RPM
    crc_val = crc16(vcat(cmd, payload))
    crc_bytes = UInt8[crc_val & 0xFF, (crc_val >> 8) & 0xFF]
    packet = UInt8[0x02, length(cmd)+length(payload), cmd..., payload..., crc_bytes..., 0x03]
    return packet
end

# Send target RPM
function send_target_rpm(vesc::SerialPort, rpm::Int)
    send_bytes(vesc, build_set_rpm_packet(rpm))
end

# Read raw packet (blocking)
function read_vesc_packet(port::SerialPort)
    packet = UInt8[]
    while true
        if bytesavailable(port) > 0
            b = read(port, UInt8)
            push!(packet, b)
            if b == 0x03 && length(packet) > 5
                return packet
            end
        end
    end
end

# Auto-detect telemetry fields
function parse_vesc_auto(data::Vector{UInt8})
    if length(data) < 16
        return nothing
    end
    # Try to scan payload for plausible Int32s (RPM, position, current)
    candidates = [reinterpret(Int32, data[i:i+3])[1] for i in 5:(length(data)-4)]
    # Simple heuristics: RPM < 100000, current < 1000
    rpm = findfirst(x -> abs(x) < 100000, candidates)
    current = findfirst(x -> abs(x) < 1000, candidates)
    position = findfirst(x -> true, candidates)  # take next available
    if rpm !== nothing && current !== nothing && position !== nothing
        return candidates[rpm], candidates[position], candidates[current]/1000
    end
    return nothing
end

# Poll telemetry
function poll_vesc(vesc::SerialPort)
    send_bytes(vesc, build_get_values_packet())
    sleep(0.05)
    if bytesavailable(vesc) > 0
        packet = read_vesc_packet(vesc)
        return parse_vesc_auto(packet)
    end
    return nothing
end

# Non-blocking user input
function read_target_rpm()
    if Base.isinteractive() && readline(stdin, keep=true) != ""
        line = chomp(readline())
        try
            new_rpm = parse(Int, line)
            global target_rpm
            target_rpm = new_rpm
            send_target_rpm(vesc, target_rpm)
            println("Sent target RPM: $target_rpm")
        catch
            println("Invalid input. Type an integer RPM.")
        end
    end
end

# --- DASHBOARD LOOP ---
println("VESC Mini Dashboard (Auto-Detect Polling Mode)")
println("Type target RPM and press Enter. Ctrl+C to stop.\n")

while true
    telemetry = poll_vesc(vesc)
    if telemetry !== nothing
        rpm, pos, curr = telemetry
        println("Target RPM: $target_rpm | Current RPM: $rpm | Position: $pos | Current: $curr")
    else
        println("Waiting for telemetry...")
    end
    read_target_rpm()
    sleep(0.1)
end
