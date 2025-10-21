using PyCall
using Printf

# Ensure the Python venv site-packages is visible
py"""
import sys
sys.path.insert(0, "/home/chumnap/fprime-venv/lib/python3.12/site-packages")
"""

# Import Python VESC class
VESC = pyimport("pyvesc.VESC").VESC

const port_name = "/dev/ttyACM0"
const baudrates = [115200, 57600]

global vesc = nothing  # Declare global upfront

for br in baudrates
    try
        println("Trying baudrate: $br ... ")
        global vesc = VESC(port_name, br)  # Use `global` here
        println("✅ Success")
        break
    catch e
        println("❌ Failed: ", e)
    end
end

if vesc === nothing
    error("Could not initialize VESC on any baudrate")
end

println("🚀 VESC Dashboard ready")
