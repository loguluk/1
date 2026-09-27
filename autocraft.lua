-- Master Factory Controller v25.0
-- Dynamic Motor State + 2-Stage Auto-Craft Integration (autocraft.lua)

local RECIPE_FILE = "recipes.json"

local monitor = peripheral.find("monitor")
if monitor then
    monitor.setTextScale(0.5)
    monitor.clear()
end
term.clear()

local modem = peripheral.find("modem")
if modem then
    rednet.open(peripheral.getName(modem))
end

local devices = {
    depotPress = "create:depot_14",
    depotArm   = "create:depot_16",
    deployer   = "create:deployer_9",
    basinPress = "create:basin_10",
    basinMixer = "create:basin_11",
    turtle     = "turtle_21",
    motor      = "electric_motor_5"
}

local recipes = {}
local currentPage = "MAIN" -- "MAIN", "SET_RPM"
local scanStage = 1

local selectedRecipeIdx = 1
local orderAmount = 1

local currentMotorSpeed = 256
local motorEnabled = true

local pendingInputIngredients = {}
local pendingOutputItems = {}
local pendingDeviceType = "UNKNOWN"
local pendingRpm = 256
local pendingMotorState = true

local lastClickTime = 0

----------------------------------------------------
-- Сохранение и Загрузка
----------------------------------------------------
function loadRecipes()
    if fs.exists(RECIPE_FILE) then
        local f = fs.open(RECIPE_FILE, "r")
        recipes = textutils.unserializeJSON(f.readAll()) or {}
        f.close()
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
function applyMotorState(speed, state)
    currentMotorSpeed = speed or currentMotorSpeed
    if state ~= nil then motorEnabled = state end

    if peripheral.isPresent(devices.motor) then
        local ok, m = pcall(peripheral.wrap, devices.motor)
        if ok and m and m.setSpeed then
            local targetRPM = motorEnabled and currentMotorSpeed or 0
            pcall(m.setSpeed, targetRPM)
            print("[MOTOR] Applied Speed: " .. targetRPM .. " RPM")
        end
    end
end

----------------------------------------------------
-- Запросы Rednet
----------------------------------------------------
function requestTurtleScan()
    rednet.broadcast({ command = "SCAN" }, "factory_net")
    local senderId, reply = rednet.receive("factory_net", 1.5)
    if reply and reply.grid then return reply.grid end
    return nil
end

function requestTurtleCraft(amount)
    rednet.broadcast({ command = "CRAFT", count = amount or 1 }, "factory_net")
    local senderId, reply = rednet.receive("factory_net", 2)
    return reply and reply.status == "OK"
end

----------------------------------------------------
-- Скан устройств
----------------------------------------------------
function safeGetDeviceItem(deviceName)
    if not peripheral.isPresent(deviceName) then return nil end
    local ok, dev = pcall(peripheral.wrap, deviceName)
    if not ok or not dev then return nil end

    if dev.getItemDetail then
        local okDetail, detail = pcall(dev.getItemDetail, 1)
        if okDetail and detail then return detail end
    end
    if dev.list then
        local okList, list = pcall(dev.list)
        if okList and list then
            for slot, item in pairs(list) do
                return item
            end
        end
    end
    return nil
end

function scanCurrentDeviceState()
    local items = {}
    local devType = "UNKNOWN"

    local turtleGrid = requestTurtleScan()
    if turtleGrid and next(turtleGrid) then
        devType = "TURTLE"
        for slot, item in pairs(turtleGrid) do
            table.insert(items, { slot = slot, name = item.name, count = item.count })
        end
        return devType, items
    end

    local handItem = safeGetDeviceItem(devices.deployer)
    local depotArmItem = safeGetDeviceItem(devices.depotArm)
    if handItem or depotArmItem then
        devType = "DEPLOYER"
        if handItem then table.insert(items, { role = "hand", name = handItem.name, count = handItem.count }) end
        if depotArmItem then table.insert(items, { role = "depot", name = depotArmItem.name, count = depotArmItem.count }) end
        return devType, items
    end

    local pressItem = safeGetDeviceItem(devices.depotPress)
    if pressItem then
        devType = "PRESS"
        table.insert(items, { role = "press_depot", name = pressItem.name, count = pressItem.count })
        return devType, items
    end

    local mixerItem = safeGetDeviceItem(devices.basinMixer) or safeGetDeviceItem(devices.basinPress)
    if mixerItem then
        devType = "MIXER"
        table.insert(items, { role = "basin", name = mixerItem.name, count = mixerItem.count })
        return devType, items
    end

    return devType, items
end

----------------------------------------------------
-- Двухэтапный Скан
----------------------------------------------------
function handleScanStep()
    if scanStage == 1 then
        local devType, items = scanCurrentDeviceState()
        if #items == 0 then
            print("[SCAN] No input items found!")
            return false
        end
        pendingDeviceType = devType
        pendingInputIngredients = items
        scanStage = 2
        return true

    elseif scanStage == 2 then
        local _, outItems = scanCurrentDeviceState()
        pendingOutputItems = outItems

        local mainOutputName = "Unknown_Item"
        if #pendingOutputItems > 0 then
            mainOutputName = pendingOutputItems[1].name:gsub(".*:", "")
        else
            mainOutputName = (pendingInputIngredients[1] and pendingInputIngredients[1].name:gsub(".*:", "")) or "Crafted_Item"
        end

        local newRecipe = {
            name = "Recipe #" .. (#recipes + 1),
            device = pendingDeviceType,
            rpm = pendingRpm,
            motorOn = pendingMotorState,
            output = mainOutputName,
            yield = (#pendingOutputItems > 0 and pendingOutputItems[1].count or 1),
            ingredients = pendingInputIngredients
        }

        table.insert(recipes, newRecipe)
        selectedRecipeIdx = #recipes
        saveRecipes()

        scanStage = 1
        pendingInputIngredients = {}
        pendingOutputItems = {}
        currentPage = "MAIN"
        return true
    end
end

----------------------------------------------------
-- Отрисовка UI
----------------------------------------------------
function drawText(termObj, x, y, text, fg, bg)
    if not termObj then return end
    termObj.setCursorPos(x, y)
    if fg then termObj.setTextColor(fg) end
    if bg then termObj.setBackgroundColor(bg) end
    termObj.write(text)
end

function drawBox(termObj, x, y, w, h, bg)
    if not termObj then return end
    termObj.setBackgroundColor(bg)
    for i = 0, h - 1 do
        termObj.setCursorPos(x, y + i)
        termObj.write(string.rep(" ", w))
    end
end

function renderUI()
    local targets = { term.current() }
    if monitor then table.insert(targets, monitor) end

    for _, t in ipairs(targets) do
        t.setBackgroundColor(colors.black)
        t.clear()
        local w, h = t.getSize()

        if currentPage == "MAIN" then
            drawText(t, 2, 1, "=== AUTO-FACTORY CONTROLLER v25 ===", colors.yellow, colors.black)
            local statusStr = motorEnabled and (currentMotorSpeed .. " RPM") or "OFF"
            drawText(t, w - 12, 1, statusStr, motorEnabled and colors.lime or colors.red, colors.black)

            if #recipes == 0 then
                drawText(t, 2, 3, "No recipes available. Click [+RECIPE] to scan.", colors.red, colors.black)
            else
                for i, r in ipairs(recipes) do
                    if i <= 5 then
                        local isSel = (i == selectedRecipeIdx)
                        local prefix = isSel and "> " or "  "
                        local bgCol = isSel and colors.gray or colors.black
                        local fgCol = isSel and colors.white or colors.cyan
                        local devTag = " [" .. (r.device or "TURTLE") .. " - " .. (r.motorOn and (r.rpm .. "RPM") or "OFF") .. "]"
                        
                        drawBox(t, 2, 2 + i, w - 4, 1, bgCol)
                        drawText(t, 2, 2 + i, prefix .. i .. ". " .. (r.output or "Item") .. devTag, fgCol, bgCol)
                    end
                end
            end

            -- Выбор количества (-64, -1, amount, +1, +10, +30, +64)
            drawBox(t, 2, h - 5, w - 4, 3, colors.gray)
            
            drawBox(t, 3, h - 4, 4, 1, colors.red)
            drawText(t, 3, h - 4, "-64", colors.white, colors.red)

            drawBox(t, 8, h - 4, 3, 1, colors.orange)
            drawText(t, 9, h - 4, "-", colors.white, colors.orange)

            drawBox(t, 12, h - 4, 8, 1, colors.black)
            drawText(t, 13, h - 4, string.format("%3d pcs", orderAmount), colors.yellow, colors.black)

            drawBox(t, 21, h - 4, 3, 1, colors.lime)
            drawText(t, 22, h - 4, "+", colors.black, colors.lime)

            drawBox(t, 25, h - 4, 4, 1, colors.green)
            drawText(t, 25, h - 4, "+10", colors.black, colors.green)

            drawBox(t, 30, h - 4, 4, 1, colors.green)
            drawText(t, 30, h - 4, "+30", colors.black, colors.green)

            drawBox(t, 35, h - 4, 4, 1, colors.green)
            drawText(t, 35, h - 4, "+64", colors.black, colors.green)

            local mBtnCol = motorEnabled and colors.lime or colors.red
            drawBox(t, 41, h - 4, 6, 1, mBtnCol)
            drawText(t, 42, h - 4, motorEnabled and "[ON]" or "[OFF]", colors.black, mBtnCol)

            drawBox(t, 48, h - 4, 7, 1, colors.cyan)
            drawText(t, 49, h - 4, "[CRAFT]", colors.black, colors.cyan)

            local btnY = h - 1
            drawBox(t, 2, btnY, 13, 1, colors.purple)
            drawText(t, 3, btnY, "[ +RECIPE ]", colors.white, colors.purple)

            drawBox(t, 17, btnY, 10, 1, colors.red)
            drawText(t, 18, btnY, "[ DELETE ]", colors.white, colors.red)

        elseif currentPage == "SET_RPM" then
            drawText(t, 2, 1, "=== RECIPE SETUP: 2-STAGE SCAN ===", colors.yellow, colors.black)

            drawText(t, 2, 3, "1. Live Motor Speed Control:", colors.white, colors.black)
            local offCol = not pendingMotorState and colors.red or colors.gray
            drawBox(t, 4, 5, 7, 1, offCol)
            drawText(t, 5, 5, "[OFF]", colors.white, offCol)

            local rpm64Col = (pendingMotorState and pendingRpm == 64) and colors.lime or colors.cyan
            drawBox(t, 12, 5, 8, 1, rpm64Col)
            drawText(t, 13, 5, "64 RPM", colors.black, rpm64Col)

            local rpm128Col = (pendingMotorState and pendingRpm == 128) and colors.lime or colors.blue
            drawBox(t, 21, 5, 9, 1, rpm128Col)
            drawText(t, 22, 5, "128 RPM", colors.white, rpm128Col)

            local rpm256Col = (pendingMotorState and pendingRpm == 256) and colors.lime or colors.purple
            drawBox(t, 31, 5, 9, 1, rpm256Col)
            drawText(t, 32, 5, "256 RPM", colors.white, rpm256Col)

            drawText(t, 2, 8, "2. Scan Recipe Sequence:", colors.white, colors.black)
            if scanStage == 1 then
                drawBox(t, 4, 10, 22, 1, colors.yellow)
                drawText(t, 5, 10, "[ 1. SCAN INPUT ITEMS ]", colors.black, colors.yellow)
                drawText(t, 4, 12, "Put raw items on Depot/Basin first!", colors.gray, colors.black)
            else
                drawBox(t, 4, 10, 23, 1, colors.lime)
                drawText(t, 5, 10, "[ 2. SCAN RESULT ITEM ]", colors.black, colors.lime)
                drawText(t, 4, 12, "Turn motor ON, let it craft, then click!", colors.gray, colors.black)
            end

            local btnY = h - 1
            drawBox(t, 2, btnY, 12, 1, colors.red)
            drawText(t, 4, btnY, "[ CANCEL ]", colors.white, colors.red)
        end
    end
end

----------------------------------------------------
-- Главный цикл
----------------------------------------------------
renderUI()

while true do
    local event, side, x, y = os.pullEvent()

    if event == "monitor_touch" or event == "mouse_click" then
        local now = os.clock()
        if now - lastClickTime >= 0.2 then
            lastClickTime = now

            local w, h = 50, 20
            if event == "monitor_touch" and monitor then
                w, h = monitor.getSize()
            else
                w, h = term.getSize()
            end

            if currentPage == "MAIN" then
                if y >= 3 and y <= 2 + math.min(#recipes, 5) then
                    selectedRecipeIdx = y - 2
                    renderUI()

                elseif y == h - 4 then
                    if x >= 3 and x <= 6 then
                        orderAmount = math.max(1, orderAmount - 64)
                        renderUI()
                    elseif x >= 8 and x <= 10 then
                        orderAmount = math.max(1, orderAmount - 1)
                        renderUI()
                    elseif x >= 21 and x <= 23 then
                        orderAmount = orderAmount + 1
                        renderUI()
                    elseif x >= 25 and x <= 28 then
                        orderAmount = orderAmount + 10
                        renderUI()
                    elseif x >= 30 and x <= 33 then
                        orderAmount = orderAmount + 30
                        renderUI()
                    elseif x >= 35 and x <= 38 then
                        orderAmount = orderAmount + 64
                        renderUI()
                    elseif x >= 41 and x <= 46 then
                        motorEnabled = not motorEnabled
                        applyMotorState(currentMotorSpeed, motorEnabled)
                        renderUI()
                    elseif x >= 48 and x <= 54 and #recipes > 0 then
                        local selR = recipes[selectedRecipeIdx]
                        if selR then
                            applyMotorState(selR.rpm or 256, selR.motorOn ~= false)
                            if selR.device == "TURTLE" then
                                requestTurtleCraft(orderAmount)
                            end
                        end
                        renderUI()
                    end

                elseif y >= h - 1 then
                    if x >= 2 and x <= 14 then
                        currentPage = "SET_RPM"
                        scanStage = 1
                        pendingRpm = currentMotorSpeed
                        pendingMotorState = motorEnabled
                        renderUI()
                    elseif x >= 17 and x <= 26 and #recipes > 0 then
                        table.remove(recipes, selectedRecipeIdx)
                        if selectedRecipeIdx > #recipes then selectedRecipeIdx = math.max(1, #recipes) end
                        saveRecipes()
                        renderUI()
                    end
                end

            elseif currentPage == "SET_RPM" then
                if y == 5 then
                    if x >= 4 and x <= 10 then
                        pendingMotorState = false
                        applyMotorState(pendingRpm, false)
                        renderUI()
                    elseif x >= 12 and x <= 19 then
                        pendingMotorState = true
                        pendingRpm = 64
                        applyMotorState(64, true)
                        renderUI()
                    elseif x >= 21 and x <= 29 then
                        pendingMotorState = true
                        pendingRpm = 128
                        applyMotorState(128, true)
                        renderUI()
                    elseif x >= 31 and x <= 39 then
                        pendingMotorState = true
                        pendingRpm = 256
                        applyMotorState(256, true)
                        renderUI()
                    end
                elseif y == 10 and x >= 4 and x <= 27 then
                    handleScanStep()
                    renderUI()
                elseif y >= h - 1 and x >= 2 and x <= 14 then
                    currentPage = "MAIN"
                    scanStage = 1
                    pendingInputIngredients = {}
                    pendingOutputItems = {}
                    renderUI()
                end
            end
        end
    end
end
