# VESC Terminal Dashboard (Stage 6c)

This project provides a **live terminal dashboard** for VESC telemetry.

## Features (Stage 6c)
- Real-time numeric telemetry display (RPM, Duty, Voltage, Temperature)
- Interactive command input:
  - `rpm <value>` → set target RPM
  - `duty <value>` → set duty cycle
  - `quit` → exit dashboard
- Automatic serial reconnect if VESC disconnects
- Terminal-only, minimal dependencies (SerialPorts, Printf, Dates)

## Usage
```bash
julia vesc_dashboard_live_v3_auto.jl

Then type commands in the terminal to control the VESC.
