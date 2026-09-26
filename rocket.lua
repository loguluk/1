local thrusters = {
    ["Front-Left (4)"]  = peripheral.wrap("liquid_vector_thruster_4"),
    ["Back-Left (5)"]   = peripheral.wrap("liquid_vector_thruster_5"),
    ["Front-Right (6)"] = peripheral.wrap("liquid_vector_thruster_6"),
    ["Back-Right (7)"]  = peripheral.wrap("liquid_vector_thruster_7")
}

print("=== SETTING ALL THRUSTERS FORWARD ===")

for name, t in pairs(thrusters) do
    if t then
        t.setVector(0, 1.0)
        print("Done: " .. name .. " -> FORWARD [0, 1.0]")
    else
        print("ERROR: " .. name .. " NOT FOUND!")
    end
end

print("Finished! All thrusters are locked FORWARD.")
