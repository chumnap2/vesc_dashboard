# VESC Terminal Dashboard (Stage 6d)

This project provides a live terminal dashboard for VESC telemetry with interactive commands.

## Features (Stage 6d)
- Real-time numeric telemetry: RPM, Duty, Voltage, Temperature
- Interactive command input:
  - `rpm <value>` → set target RPM
  - `duty <value>` → set duty cycle
  - `quit` → exit dashboard
- Automatic serial reconnect if VESC disconnects
- CSV logging of telemetry on exit (`vesc_telemetry_log.csv`)
- Terminal-only, minimal dependencies

## Usage
```bash
julia vesc_dashboard_live_v3_auto.jl

Type commands directly in the terminal while telemetry updates.
