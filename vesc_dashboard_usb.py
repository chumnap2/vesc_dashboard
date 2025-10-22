#!/usr/bin/env python3
import time
import serial
from pyvesc.VESC import VESC
from pyvesc.VESC import GetValues

# ===============================
# CONFIGURATION
# ===============================
port_name = '/dev/ttyACM0'
baudrate = 115200
poll_interval = 0.5  # seconds

print(f"Opening serial port: {port_name} at {baudrate} baud...")
ser = serial.Serial(port_name, baudrate, timeout=1)
vesc = VESC(serial_port=ser)
print("Serial port opened.\n")

# ===============================
# MAIN LOOP
# ===============================
print("🚀 VESC USB Dashboard (Polling Mode)")
try:
    while True:
        try:
            # Get VESC telemetry
            values = vesc.get_values()

            # Print selected telemetry
            print(f"Voltage: {values.v_in:.2f} V | "
                  f"Current: {values.avg_motor_current:.2f} A | "
                  f"RPM: {values.rpm:.0f} | "
                  f"Duty: {values.duty_cycle*100:.1f}% | "
                  f"Ah: {values.amp_hours:.2f} | "
                  f"Motor Temp: {values.t_motor:.1f}°C")

        except Exception as e:
            print(f"⚠️  Error reading VESC: {e}")

        time.sleep(poll_interval)

except KeyboardInterrupt:
    print("\nExiting VESC dashboard.")
    ser.close()
