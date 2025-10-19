# Stage4MakieLive — Real-Time RPM & Position Telemetry with Makie.jl

This project simulates a live telemetry system for a motor controller using
**Julia** + **Makie.jl** visualization, inspired by NASA F´ (F Prime) architecture.

---

## 🚀 Features
- Real-time RPM and Position simulation loop  
- Live updating plots using `GLMakie`  
- Interactive console input to change target RPM  
- Thread-safe updates with asynchronous command listener  

---

## 🧩 Requirements
- Julia ≥ 1.10
- `GLMakie.jl`

Install dependencies:
```julia
using Pkg
Pkg.activate(".")
Pkg.instantiate()

▶️ Run
julia stage4_makie_live_fixed.jl

📡 Example

When running, you’ll see:
Enter new target RPM: 200
[TELEMETRY] RPM=200.0 Pos=120.3

⚖️ License

MIT License © 2025 chumnap thach
