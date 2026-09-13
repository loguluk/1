-- ===================================================
-- DOOM 3D ENGINE V2.0 FOR COMPUTERCRAFT
-- Features: Multi-Layer ASCII Sprites, AI Patrol, Z-Buffer
-- ===================================================

local display = peripheral.find("monitor") or term
if display.setTextScale then display.setTextScale(0.5) end
local w, h = display.getSize()

local buffer = {}
local zBuffer = {}

local function initBuffer()
    buffer = {}
    for y = 1, h do
        buffer[y] = {}
        for x = 1, w do
            buffer[y][x] = {char = " ", fg = colors.white, bg = colors.black}
        end
    end
end

local function setPixel(x, y, char, fg, bg)
    x, y = math.floor(x), math.floor(y)
    if x >= 1 and x <= w and y >= 1 and y <= h then
        buffer[y][x] = {char = char or " ", fg = fg or colors.white, bg = bg or colors.black}
    end
end

local function renderBuffer()
    for y = 1, h do
        display.setCursorPos(1, y)
        for x = 1, w do
            local p = buffer[y][x]
            display.setTextColor(p.fg)
            display.setBackgroundColor(p.bg)
            display.write(p.char)
        end
    end
end

local Sprites = {
    weapon = {
        idle = {
            "   ||   ",
            "   ||   ",
            "  /==\\  ",
            " [|  |] "
        },
        fire = {
            " (\\/\\/) ",
            "==[XX]==",
            "   ||   ",
            "  /==\\  "
        }
    },
    monster = {
        lines = {
            " /\\__/\\ ",
            "( o.o ) ",
            " > ^ <  ",
            " /| |\\  "
        },
        fg = colors.white,
        bg = colors.red
    }
}

local mapWidth, mapHeight = 12, 12
local map = {
    {1,1,1,1,1,1,1,1,1,1,1,1},
    {1,0,0,0,0,1,0,0,0,0,0,1},
    {1,0,2,2,0,1,0,3,3,3,0,1},
    {1,0,2,0,0,0,0,0,0,3,0,1},
    {1,0,0,0,1,1,1,0,0,0,0,1},
    {1,0,0,0,1,0,0,0,0,0,0,1},
    {1,0,3,0,1,0,2,2,2,0,0,1},
    {1,0,3,0,0,0,2,0,0,0,0,1},
    {1,0,3,3,3,0,2,0,1,1,0,1},
    {1,0,0,0,0,0,0,0,1,0,0,1},
    {1,0,0,0,0,0,0,0,0,0,0,1},
    {1,1,1,1,1,1,1,1,1,1,1,1}
}

local wallColors = {
    [1] = {near = colors.gray, far = colors.black},
    [2] = {near = colors.red, far = colors.brown},
    [3] = {near = colors.blue, far = colors.cyan}
}

local player = {x = 2.5, y = 2.5, angle = 0, health = 100, ammo = 50, score = 0}
local enemies = {
    {x = 6.5, y = 3.5, health = 30, alive = true, dir = 1},
    {x = 9.5, y = 8.5, health = 30, alive = true, dir = -1},
    {x = 3.5, y = 9.5, health = 30, alive = true, dir = 1}
}

local isShooting = false
local running = true

local function updateAI()
    for _, e in ipairs(enemies) do
        if e.alive then
            e.x = e.x + (0.02 * e.dir)
            if map[math.floor(e.y)][math.floor(e.x)] > 0 then
                e.dir = e.dir * -1
            end
        end
    end
end

local function render3D()
    initBuffer()
    local renderH = h - 4
    local fov = math.pi / 3
    local halfFov = fov / 2

    for col = 1, w do
        local rayAngle = (player.angle - halfFov) + (col / w) * fov
        local distance = 0
        local hitWall = false
        local wallType = 1
        local cosA, sinA = math.cos(rayAngle), math.sin(rayAngle)

        while not hitWall and distance < 16 do
            distance = distance + 0.08
            local checkX = math.floor(player.x + cosA * distance)
            local checkY = math.floor(player.y + sinA * distance)

            if checkY < 1 or checkY > mapHeight or checkX < 1 or checkX > mapWidth then
                hitWall = true distance = 16
            elseif map[checkY][checkX] > 0 then
                hitWall = true wallType = map[checkY][checkX]
            end
        end

        local correctDist = distance * math.cos(rayAngle - player.angle)
        zBuffer[col] = correctDist

        local wallHeight = math.floor(renderH / (correctDist + 0.1))
        if wallHeight > renderH then wallHeight = renderH end

        local eye = math.floor(renderH / 2)
        local startY = eye - math.floor(wallHeight / 2)
        local endY = eye + math.floor(wallHeight / 2)

        local colorData = wallColors[wallType] or wallColors[1]
        local activeWallColor = correctDist < 5 and colorData.near or colorData.far

        for y = 1, renderH do
            if y < startY then
                setPixel(col, y, " ", colors.white, colors.black)
            elseif y >= startY and y <= endY then
                setPixel(col, y, "#", colors.white, activeWallColor)
            else
                setPixel(col, y, ".", colors.gray, colors.black)
            end
        end
    end

    for _, e in ipairs(enemies) do
        if e.alive then
            local dx = e.x - player.x
            local dy = e.y - player.y
            local spriteDist = math.sqrt(dx * dx + dy * dy)

            local spriteAngle = math.atan2(dy, dx) - player.angle
            while spriteAngle < -math.pi do spriteAngle = spriteAngle + 2 * math.pi end
            while spriteAngle > math.pi do spriteAngle = spriteAngle - 2 * math.pi end

            if math.abs(spriteAngle) < halfFov then
                local screenX = math.floor((w / 2) + (spriteAngle / fov) * w)
                local spriteLines = Sprites.monster.lines
                local spriteH = #spriteLines
                local spriteW = string.len(spriteLines[1])

                local scale = math.max(1, math.floor(3 / (spriteDist + 0.1)))
                local startY = math.floor((renderH / 2) - ((spriteH * scale) / 2))

                for row = 1, spriteH do
                    local line = spriteLines[row]
                    for col = 1, spriteW do
                        local char = string.sub(line, col, col)
                        if char ~= " " then
                            local drawX = screenX + math.floor((col - spriteW / 2) * scale)
                            local drawY = startY + math.floor((row - 1) * scale)

                            if drawX >= 1 and drawX <= w and drawY >= 1 and drawY <= renderH then
                                if spriteDist < (zBuffer[drawX] or 16) then
                                    setPixel(drawX, drawY, char, Sprites.monster.fg, Sprites.monster.bg)
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    local cx = math.floor(w / 2)
    setPixel(cx, math.floor(renderH / 2), "+", colors.red, colors.black)

    local currentWeaponFrame = isShooting and Sprites.weapon.fire or Sprites.weapon.idle
    local weaponH = #currentWeaponFrame
    local weaponW = string.len(currentWeaponFrame[1])
    local wStartX = math.floor((w - weaponW) / 2)
    local wStartY = renderH - weaponH + 1

    for row = 1, weaponH do
        local line = currentWeaponFrame[row]
        for col = 1, weaponW do
            local char = string.sub(line, col, col)
            if char ~= " " then
                local fgColor = isShooting and colors.yellow or colors.lightGray
                local bgColor = isShooting and colors.orange or colors.gray
                setPixel(wStartX + col - 1, wStartY + row - 1, char, fgColor, bgColor)
            end
        end
    end
    if isShooting then isShooting = false end

    for my = 1, mapHeight do
        for mx = 1, mapWidth do
            local char = map[my][mx] > 0 and "#" or " "
            setPixel(w - mapWidth + mx, my, char, colors.gray, colors.black)
        end
    end
    setPixel(w - mapWidth + math.floor(player.x), math.floor(player.y), "P", colors.yellow, colors.black)

    for x = 1, w do
        for y = renderH + 1, h do
            setPixel(x, y, " ", colors.white, colors.gray)
        end
    end

    setPixel(1, h - 3, "HP: " .. player.health .. "% | AMMO: " .. player.ammo .. " | SCORE: " .. player.score, colors.yellow, colors.gray)
    setPixel(2, h - 1, "[< TURN]", colors.white, colors.blue)
    setPixel(11, h - 1, "[FWD]", colors.white, colors.green)
    setPixel(17, h - 1, "[BACK]", colors.white, colors.green)
    setPixel(24, h - 1, "[TURN >]", colors.white, colors.blue)
    setPixel(33, h - 1, "[ FIRE! ]", colors.white, colors.red)

    renderBuffer()
end

local function movePlayer(dir)
    local moveSpeed = 0.35 * dir
    local nextX = player.x + math.cos(player.angle) * moveSpeed
    local nextY = player.y + math.sin(player.angle) * moveSpeed

    if map[math.floor(nextY)][math.floor(player.x)] == 0 then player.y = nextY end
    if map[math.floor(player.y)][math.floor(nextX)] == 0 then player.x = nextX end
end

local function fireWeapon()
    if player.ammo <= 0 then return end
    player.ammo = player.ammo - 1
    isShooting = true

    for _, e in ipairs(enemies) do
        if e.alive then
            local dx = e.x - player.x
            local dy = e.y - player.y
            local spriteAngle = math.atan2(dy, dx) - player.angle
            while spriteAngle < -math.pi do spriteAngle = spriteAngle + 2 * math.pi end
            while spriteAngle > math.pi do spriteAngle = spriteAngle - 2 * math.pi end

            if math.abs(spriteAngle) < 0.25 then
                e.health = e.health - 15
                if e.health <= 0 then
                    e.alive = false
                    player.score = player.score + 100
                end
            end
        end
    end
end

render3D()

while running do
    local event, p1, p2, p3 = os.pullEvent()

    updateAI()

    if event == "key" then
        if p1 == keys.w or p1 == keys.up then movePlayer(1) end
        if p1 == keys.s or p1 == keys.down then movePlayer(-1) end
        if p1 == keys.a or p1 == keys.left then player.angle = player.angle - 0.2 end
        if p1 == keys.d or p1 == keys.right then player.angle = player.angle + 0.2 end
        if p1 == keys.space then fireWeapon() end
        if p1 == keys.q then running = false end
        render3D()
    end

    if event == "monitor_touch" or event == "mouse_click" then
        local x, y = p2, p3
        if y >= h - 2 then
            if x >= 2 and x <= 9 then player.angle = player.angle - 0.25
            elseif x >= 11 and x <= 15 then movePlayer(1)
            elseif x >= 17 and x <= 22 then movePlayer(-1)
            elseif x >= 24 and x <= 31 then player.angle = player.angle + 0.25
            elseif x >= 33 and x <= 41 then fireWeapon() end
            render3D()
        end
    end
end