local thrusters = {
    ["Front-Left (4)"]  = peripheral.wrap("liquid_vector_thruster_4"),
    ["Back-Left (5)"]   = peripheral.wrap("liquid_vector_thruster_5"),
    ["Front-Right (6)"] = peripheral.wrap("liquid_vector_thruster_6"),
    ["Back-Right (7)"]  = peripheral.wrap("liquid_vector_thruster_7")
}

print("=== FORWARD VECTOR TEST ===")
print("Setting all thrusters MAX FORWARD (Y = 1.0)...")

for name, t in pairs(thrusters) do
    if t then
        -- Set Y to 1.0 (Maximum Forward tilt)
        t.setVector(0, 1.0)
        print("Set " .. name .. " -> FORWARD [0, 1.0]")
    else
        print("ERROR: " .. name .. " NOT FOUND!")
    end
end

print("\nAll thrusters are now set to MAX FORWARD.")
print("Check each engine with Wrench if needed!")
print("Press ENTER to reset back to normal [0, 0]...")
read()

for name, t in pairs(thrusters) do
    if t then
        t.setVector(0, 0)
    end
end

print("Reset complete! Thrusters back to [0, 0].")
