using PyCall

py"""
import sys, os

# Ensure PyCall uses the same Python environment
venv_site = "/home/chumnap/fprime-venv/lib/python3.12/site-packages"
if venv_site not in sys.path:
    sys.path.insert(0, venv_site)
    print("🔧 Added to sys.path:", venv_site)

print("Python executable:", sys.executable)
print("Python sys.path:")
for p in sys.path:
    print("  ", p)

try:
    import pyvesc_fix
    print("✅ Successfully imported pyvesc_fix")
except Exception as e:
    print("❌ Still failed:", e)
"""
