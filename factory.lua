-- Master Factory Controller (5x4 Monitor GUI & Turtle 3x3 Grid)

local RECIPE_FILE = "recipes.json"

local monitor = peripheral.find("monitor")
if not monitor then
    error("Error: Monitor not found!")
end

monitor.setTextScale(0.5)
monitor.clear()

local mW, mH = monitor.getSize()

local devices = {
    depotPress = "create:depot_14",
    depotArm   = "create:depot_16",
    deployer   = "create:deployer_9",
    basinPress = "create:basin_10",
    basinMixer = "create:basin_11",
    turtle     = "turtle_21"
}

-- Автопоиск мотора
local motorName = nil
for _, name in ipairs(peripheral.getNames()) do
    if name:find("electric_motor") or peripheral.getType(name) == "create:electric_motor" then
        motorName = name
        break
    end
end

local recipes = {}
local currentPage = "MAIN" -- "MAIN", "RECORD", "VIEW"
local currentRecipeIdx = 1

local isRecording = false
local currentRecordingData = {
    grid3x3 = {},
    inputs = {},
    outputs = {},
    logs = {}
}
local initialSnap = {}
local currentSpeed = 0

----------------------------------------------------
-- Сохранение / Загрузка
----------------------------------------------------
function loadRecipes()
    if fs.exists(RECIPE_FILE) then
        local f = fs.open(RECIPE_FILE, "r")
        local data = f.readAll()
        f.close()
        recipes = textutils.unserializeJSON(data) or {}
    end
end

function saveRecipes()
    local f = fs.open(RECIPE_FILE, "w")
    f.write(textutils.serializeJSON(recipes))
    f.close()
end

loadRecipes()

----------------------------------------------------
-- Управление Мотором
----------------------------------------------------
function setMotorSpeed(speed)
    currentSpeed = speed
    if motorName and peripheral.isPresent(motorName) then
        local m = peripheral.wrap(motorName)
        if m and m.setSpeed then
            m.setSpeed(speed)
            return true
        end
    end
    return false
end

----------------------------------------------------
-- Отрисовка UI
----------------------------------------------------
function drawButton(x, y, w, h, bg, textColor, text)
    monitor.setBackgroundColor(bg)
    monitor.setTextColor(textColor)
    for i = 0, h - 1 do
        monitor.setCursorPos(x, y + i)
        monitor.write(string.rep(" ", w))
    end
    local textX = x + math.floor((w - #text) / 2)
    monitor.setCursorPos(textX, y + math.floor(h / 2))
    monitor.write(text)
    monitor.setBackgroundColor(colors.black)
end

function snapshotInventories()
    local snap = {}
    for label, devName in pairs(devices) do
        if peripheral.isPresent(devName) then
            local p = peripheral.wrap(devName)
            if p and p.list then
                snap[devName] = {}
                local items = p.list()
                for slot, item in pairs(items) do
                    snap[devName][slot] = { name = item.name, count = item.count }
                end
            end
        end
    end
    return snap
end

----------------------------------------------------
-- ЭКРАН 1: Главное меню
----------------------------------------------------
function drawMainPage()
    monitor.setBackgroundColor(colors.black)
    monitor.clear()

    monitor.setCursorPos(2, 2)
    monitor.setTextColor(colors.yellow)
    monitor.write("======================== AUTO-FACTORY CONTROLLER (5x4 MONITOR) ========================")

    monitor.setCursorPos(2, 4)
    monitor.setTextColor(colors.cyan)
    monitor.write("CONNECTED DEVICES & MOTOR STATUS:")

    local statusY = 5
    local col = 4
    for label, name in pairs(devices) do
        monitor.setCursorPos(col, statusY)
        if peripheral.isPresent(name) then
            monitor.setTextColor(colors.green)
            monitor.write("[+] " .. label .. " (" .. name .. ")")
        else
            monitor.setTextColor(colors.red)
            monitor.write("[-] " .. label .. " (OFFLINE)")
        end
        statusY = statusY + 1
        if statusY > 8 then
            statusY = 5
            col = col + 44
        end
    end

    monitor.setCursorPos(4, 8)
    if motorName and peripheral.isPresent(motorName) then
        monitor.setTextColor(colors.green)
        monitor.write("[+] Electric Motor (" .. motorName .. ") -> " .. currentSpeed .. " RPM")
    else
        monitor.setTextColor(colors.yellow)
        monitor.write("[-] Electric Motor (Not found)")
    end

    monitor.setCursorPos(2, 11)
    monitor.setTextColor(colors.orange)
    monitor.write("SAVED RECIPES (" .. #recipes .. "):")

    for i, r in ipairs(recipes) do
        if i <= 5 then
            monitor.setCursorPos(4, 11 + i)
            monitor.setTextColor(colors.lightBlue)
            monitor.write(i .. ". " .. (r.name or "Recipe") .. " -> " .. (r.output or "Unknown"))
        end
    end

    local btnY = mH - 3
    drawButton(2, btnY, 30, 3, colors.blue, colors.white, "[ RECORD RECIPE ]")
    drawButton(34, btnY, 28, 3, colors.purple, colors.white, "[ VIEW RECIPES ]")
    drawButton(64, btnY, 24, 3, colors.gray, colors.white, "[ REFRESH ]")
end

----------------------------------------------------
-- ЭКРАН 2: Окно создания крафта (Record)
----------------------------------------------------
function drawRecordPage()
    monitor.setBackgroundColor(colors.black)
    monitor.clear()

    monitor.setCursorPos(2, 2)
    monitor.setTextColor(colors.red)
    monitor.write("========================= RECORDER MODE (TURTLE 3x3 GRID) =========================")

    monitor.setCursorPos(2, 4)
    monitor.setTextColor(colors.white)
    monitor.write("ELECTRIC MOTOR SPEED: ")
    monitor.setTextColor(currentSpeed > 0 and colors.green or colors.red)
    monitor.write(currentSpeed .. " RPM")

    monitor.setCursorPos(2, 6)
    monitor.setTextColor(colors.yellow)
    monitor.write("TURTLE 3x3 CRAFTING GRID (SLOTS 1-9):")

    local currentSnap = snapshotInventories()
    local turtleSnap = currentSnap[devices.turtle] or {}

    -- Отрисовка 3x3
    for row = 0, 2 do
        for col = 0, 2 do
            local slot = row * 3 + col + 1
            local item = turtleSnap[slot]
            local x = 4 + col * 26
            local y = 7 + row

            monitor.setCursorPos(x, y)
            if item then
                monitor.setTextColor(colors.lime)
                monitor.write(string.format("[%d] %dx%s", slot, item.count, item.name:gsub(".*:", ""):sub(1, 12)))
            else
                monitor.setTextColor(colors.gray)
                monitor.write(string.format("[%d] ------------", slot))
            end
        end
    end

    monitor.setCursorPos(2, 11)
    monitor.setTextColor(colors.cyan)
    monitor.write("MACHINES INVENTORY STATUS:")
    local lineY = 12

    for label, devName in pairs(devices) do
        if devName ~= devices.turtle and currentSnap[devName] then
            for slot, item in pairs(currentSnap[devName]) do
                if lineY <= 15 then
                    monitor.setCursorPos(4, lineY)
                    monitor.setTextColor(colors.lightBlue)
                    monitor.write("-> " .. label .. ": " .. item.count .. "x " .. item.name:gsub(".*:", ""))
                    lineY = lineY + 1
                end
            end
        end
    end

    if lineY == 12 then
        monitor.setCursorPos(4, 12)
        monitor.setTextColor(colors.gray)
        monitor.write("(No items on depots/basins...)")
    end

    monitor.setCursorPos(2, 17)
    monitor.setTextColor(colors.orange)
    monitor.write("LOG: ")
    if #currentRecordingData.logs > 0 then
        monitor.setTextColor(colors.white)
        monitor.write(currentRecordingData.logs[#currentRecordingData.logs])
    end

    drawButton(2, 19, 22, 2, colors.red, colors.white, "[ MOTOR 0 ]")
    drawButton(26, 19, 22, 2, colors.orange, colors.white, "[ MOTOR 128 ]")
    drawButton(50, 19, 22, 2, colors.green, colors.black, "[ MOTOR 256 ]")

    local btnY = mH - 3
    drawButton(2, btnY, 36, 3, colors.blue, colors.white, "[ SAVE RECIPE ]")
    drawButton(40, btnY, 36, 3, colors.gray, colors.white, "[ CANCEL ]")
end

----------------------------------------------------
-- ЭКРАН 3: Просмотр Рецептов
----------------------------------------------------
function drawViewPage()
    monitor.setBackgroundColor(colors.black)
    monitor.clear()

    monitor.setCursorPos(2, 2)
    monitor.setTextColor(colors.purple)
    monitor.write("=============================== RECIPE VIEWER ===============================")

    if #recipes == 0 then
        monitor.setCursorPos(4, 6)
        monitor.setTextColor(colors.gray)
        monitor.write("No recipes recorded yet.")
    else
        local r = recipes[currentRecipeIdx]
        monitor.setCursorPos(2, 4)
        monitor.setTextColor(colors.yellow)
        monitor.write("Recipe " .. currentRecipeIdx .. " / " .. #recipes .. ": " .. (r.name or "Unnamed"))

        monitor.setCursorPos(2, 6)
        monitor.setTextColor(colors.cyan)
        monitor.write("Turtle 3x3 Grid Setup:")

        local grid = r.grid3x3 or {}
        for row = 0, 2 do
            for col = 0, 2 do
                local slot = row * 3 + col + 1
                local item = grid[slot]
                local x = 4 + col * 26
                local y = 7 + row

                monitor.setCursorPos(x, y)
                if item then
                    monitor.setTextColor(colors.lime)
                    monitor.write(string.format("[%d] %dx%s", slot, item.count, item.name:gsub(".*:", ""):sub(1, 12)))
                else
                    monitor.setTextColor(colors.gray)
                    monitor.write(string.format("[%d] ------------", slot))
                end
            end
        end

        monitor.setCursorPos(2, 12)
        monitor.setTextColor(colors.orange)
        monitor.write("Output Item: " .. (r.output or "Unknown"))
    end

    local btnY = mH - 3
    drawButton(2, btnY, 22, 3, colors.gray, colors.white, "[ PREV ]")
    drawButton(26, btnY, 22, 3, colors.gray, colors.white, "[ NEXT ]")
    drawButton(50, btnY, 28, 3, colors.red, colors.white, "[ BACK TO MAIN ]")
end

----------------------------------------------------
-- Логика Записи
----------------------------------------------------
function startRecording()
    currentPage = "RECORD"
    isRecording = true
    setMotorSpeed(0)
    initialSnap = snapshotInventories()
    currentRecordingData = {
        grid3x3 = {},
        inputs = {},
        outputs = {},
        logs = { "Crafting window opened. Motor set to 0 RPM." }
    }
    drawRecordPage()
end

function processRecordingStep()
    if not isRecording then return end
    local nowSnap = snapshotInventories()

    for devName, slots in pairs(nowSnap) do
        local shortLabel = devName
        for l, n in pairs(devices) do
            if n == devName then shortLabel = l break end
        end

        for slot, item in pairs(slots) do
            local prevCount = (initialSnap[devName] and initialSnap[devName][slot]) and initialSnap[devName][slot].count or 0
            local diff = item.count - prevCount

            if diff > 0 then
                local logMsg = "+" .. diff .. " " .. item.name:gsub(".*:", "") .. " at " .. shortLabel
                if #currentRecordingData.logs == 0 or currentRecordingData.logs[#currentRecordingData.logs] ~= logMsg then
                    table.insert(currentRecordingData.logs, logMsg)
                    currentRecordingData.output = item.name
                end
            end
        end
    end

    if nowSnap[devices.turtle] then
        for slot = 1, 9 do
            if nowSnap[devices.turtle][slot] then
                currentRecordingData.grid3x3[slot] = nowSnap[devices.turtle][slot]
            end
        end
    end

    drawRecordPage()
end

function saveCurrentRecipe()
    local recipeName = "Recipe_" .. (#recipes + 1)
    local newRecipe = {
        name = recipeName,
        grid3x3 = currentRecordingData.grid3x3,
        output = currentRecordingData.output or "Process_Done",
        timestamp = os.time()
    }

    table.insert(recipes, newRecipe)
    saveRecipes()

    isRecording = false
    setMotorSpeed(0)
    currentPage = "MAIN"
    drawMainPage()
end

----------------------------------------------------
-- Главный Цикл
----------------------------------------------------
drawMainPage()

parallel.waitForAny(
    function()
        while true do
            local event, side, x, y = os.pullEvent("monitor_touch")
            local btnY = mH - 3

            if currentPage == "MAIN" then
                if y >= btnY and y <= btnY + 2 then
                    if x >= 2 and x <= 31 then
                        startRecording()
                    elseif x >= 34 and x <= 61 then
                        currentPage = "VIEW"
                        drawViewPage()
                    elseif x >= 64 and x <= 88 then
                        drawMainPage()
                    end
                end

            elseif currentPage == "RECORD" then
                if y >= 19 and y <= 20 then
                    if x >= 2 and x <= 23 then setMotorSpeed(0) drawRecordPage()
                    elseif x >= 26 and x <= 47 then setMotorSpeed(128) drawRecordPage()
                    elseif x >= 50 and x <= 71 then setMotorSpeed(256) drawRecordPage()
                    end
                elseif y >= btnY and y <= btnY + 2 then
                    if x >= 2 and x <= 37 then
                        saveCurrentRecipe()
                    elseif x >= 40 and x <= 76 then
                        isRecording = false
                        setMotorSpeed(0)
                        currentPage = "MAIN"
                        drawMainPage()
                    end
                end

            elseif currentPage == "VIEW" then
                if y >= btnY and y <= btnY + 2 then
                    if x >= 2 and x <= 23 then
                        if currentRecipeIdx > 1 then currentRecipeIdx = currentRecipeIdx - 1 drawViewPage() end
                    elseif x >= 26 and x <= 47 then
                        if currentRecipeIdx < #recipes then currentRecipeIdx = currentRecipeIdx + 1 drawViewPage() end
                    elseif x >= 50 and x <= 77 then
                        currentPage = "MAIN"
                        drawMainPage()
                    end
                end
            end
        end
    end,

    function()
        while true do
            sleep(1)
            if isRecording and currentPage == "RECORD" then
                processRecordingStep()
            end
        end
    end
)
