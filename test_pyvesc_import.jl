using PyCall

py"""
import sys
print("Python executable:", sys.executable)
print("Python sys.path:")
for p in sys.path:
    print("  ", p)

print("\n--- Testing imports ---")
for name in ["pyvesc_fix", "pyvesc", "pyvesc.VESC", "pyvesc_fix.VESC"]:
    try:
        mod = __import__(name)
        print("✅ Imported:", name, "->", mod)
    except Exception as e:
        print("❌ Failed:", name, "->", e)
"""
