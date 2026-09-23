-- Master Drone Controller (Fixed Forward/Backward & Left/Right Strafe)

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

-- Flight Parameters
local baseSpeed = 0
local maxSpeed  = 256
local tilt      = 12 -- Сила наклона при движении

-- Main PC Inputs
local sideThrustUp   = "back"
local sideThrustDown = "right"

-- Relay Inputs
local sideMoveForward  = "front"
local sideMoveBackward = "back"
local sideMoveLeft     = "left"
local sideMoveRight    = "right"

term.clear()
term.setCursorPos(1, 1)
print("=== DRONE CONTROLLER (FIXED DIRECTION) ===")

while true do
    local isThrustUp   = rs.getInput(sideThrustUp)
    local isThrustDown = rs.getInput(sideThrustDown)

    local isForward  = redstoneRelay.getInput(sideMoveForward)
    local isBackward = redstoneRelay.getInput(sideMoveBackward)
    local isLeft     = redstoneRelay.getInput(sideMoveLeft)
    local isRight    = redstoneRelay.getInput(sideMoveRight)

    -- 1. Thrust Control
    if isThrustUp then
        baseSpeed = math.min(maxSpeed, baseSpeed + 2)
    elseif isThrustDown then
        baseSpeed = math.max(0, baseSpeed - 2)
    end

    -- 2. Direction Vectors
    local pitch = 0 -- Вперед (+1) / Назад (-1)
    local roll  = 0 -- Вправо (+1) / Влево (-1)

    if isForward then pitch = 1 end
    if isBackward then pitch = -1 end
    if isLeft then roll = -1 end
    if isRight then roll = 1 end

    -- 3. Calculate Individual Motor Speeds
    -- Pitch: Вперед -> задние моторы убавляют/передние прибавляют (и наоборот)
    -- Roll: Вправо -> правые моторы убавляют/левые прибавляют
    local speedFL = math.max(0, math.min(maxSpeed, baseSpeed + (pitch * tilt) + (roll * tilt)))
    local speedFR = math.max(0, math.min(maxSpeed, baseSpeed + (pitch * tilt) - (roll * tilt)))
    local speedBL = math.max(0, math.min(maxSpeed, baseSpeed - (pitch * tilt) + (roll * tilt)))
    local speedBR = math.max(0, math.min(maxSpeed, baseSpeed - (pitch * tilt) - (roll * tilt)))

    -- 4. Send Speeds
    rednet.send(idFL, speedFL, "drone_control")
    rednet.send(idFR, speedFR, "drone_control")
    rednet.send(idBL, speedBL, "drone_control")
    rednet.send(idBR, speedBR, "drone_control")

    sleep(0.05)
end
