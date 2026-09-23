-- Master Drone Controller (Flight + Relay TOP Signal to PC #26)

local modemSide = nil
for _, side in ipairs(rs.getSides()) do
    if peripheral.getType(side) == "modem" then
        modemSide = side
        break
    end
end

if not modemSide then
    print("ERROR: Modem not found!")
    return
end

rednet.open(modemSide)

local redstoneRelay = peripheral.find("redstone_relay")
if not redstoneRelay then
    print("ERROR: Redstone Relay not found!")
    return
end

-- Turtle IDs
local idFL = 5 -- Front Left
local idFR = 4 -- Front Right
local idBL = 6 -- Back Left
local idBR = 3 -- Back Right

-- Target Receiver Computer
local TARGET_PC_ID = 26

-- Flight Parameters
local baseSpeed = 0
local maxSpeed  = 256
local tilt      = 12

-- Main PC Inputs (Thrust)
local sideThrustUp   = "back"
local sideThrustDown = "right"

-- Relay Inputs (Flight & Remote Signal)
local sideMoveForward  = "front"
local sideMoveBackward = "back"
local sideMoveLeft     = "left"
local sideMoveRight    = "right"
local sideTopSignal    = "top" -- Сигнал сверху от Redstone Relay

-- Timer for Rednet Cooldown
local lastSendTime = 0

term.clear()
term.setCursorPos(1, 1)
print("=== DRONE CONTROLLER + RELAY SENDER ===")
print("Target Receiver PC ID: " .. TARGET_PC_ID)

while true do
    -- 1. Read Flight Inputs
    local isThrustUp   = rs.getInput(sideThrustUp)
    local isThrustDown = rs.getInput(sideThrustDown)

    local isForward  = redstoneRelay.getInput(sideMoveForward)
    local isBackward = redstoneRelay.getInput(sideMoveBackward)
    local isLeft     = redstoneRelay.getInput(sideMoveLeft)
    local isRight    = redstoneRelay.getInput(sideMoveRight)

    -- 2. Read TOP Signal from Redstone Relay & Send to PC 26
    local isTopActive = redstoneRelay.getInput(sideTopSignal)
    local currentTime = os.epoch("utc")

    if isTopActive and (currentTime - lastSendTime > 1000) then
        rednet.send(TARGET_PC_ID, "top_signal_active", "relay_pass")
        print("[" .. os.time() .. "] Signal from Relay TOP sent to PC #" .. TARGET_PC_ID)
        lastSendTime = currentTime
    end

    -- 3. Thrust Logic
    if isThrustUp then
        baseSpeed = math.min(maxSpeed, baseSpeed + 2)
    elseif isThrustDown then
        baseSpeed = math.max(0, baseSpeed - 2)
    end

    -- 4. Pitch & Roll Vectors
    local pitch = 0
    local roll  = 0

    if isForward then pitch = 1 end
    if isBackward then pitch = -1 end
    if isLeft then roll = -1 end
    if isRight then roll = 1 end

    -- 5. Calculate Motor Speeds
    local speedFL = math.max(0, math.min(maxSpeed, baseSpeed + (pitch * tilt) + (roll * tilt)))
    local speedFR = math.max(0, math.min(maxSpeed, baseSpeed + (pitch * tilt) - (roll * tilt)))
    local speedBL = math.max(0, math.min(maxSpeed, baseSpeed - (pitch * tilt) + (roll * tilt)))
    local speedBR = math.max(0, math.min(maxSpeed, baseSpeed - (pitch * tilt) - (roll * tilt)))

    -- 6. Send to Turtles
    rednet.send(idFL, speedFL, "drone_control")
    rednet.send(idFR, speedFR, "drone_control")
    rednet.send(idBL, speedBL, "drone_control")
    rednet.send(idBR, speedBR, "drone_control")

    sleep(0.05)
end
