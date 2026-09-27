-- Master Factory Controller v24.0
-- Two-Step Recipe Scanning (Input -> Motor Processing -> Result), Extended Quantity Controls (+1, +10, +30, +64)

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

local silos = {
    "create_connected:item_silo_94",
    "create_connected:item_silo_95",
    "create_connected:item_silo_96",
    "create_connected:item_silo_97",
    "create_connected:item_silo_98",
    "create_connected:item_silo_101",
    "create_connected:item_silo_100",
    "create_connected:item_silo_99"
}

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
local selectedRecipeIdx = 1
local orderAmount = 1

local currentMotorSpeed = 256
local motorEnabled = true

local scanStep = 1 -- 1: Scan Inputs, 2: Scan Output
local pendingIngredients = {}
local pendingDeviceType = "TURTLE"
local pendingRpm = 256
local pendingMotorState = true

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
            print("[MOTOR] Speed applied: " .. targetRPM .. " RPM")
        end
    end
end

----------------------------------------------------
-- Сетевой обмен Rednet
----------------------------------------------------
function requestTurtleScan()
    rednet.broadcast({ command = "SCAN" }, "factory_net")
    local senderId, reply = rednet.receive("factory_net", 2)
    if reply and reply.grid then return reply.grid end
    return nil
end

function requestTurtleCraft(amount)
    rednet.broadcast({ command = "CRAFT", count = amount or 1 }, "factory_net")
    local senderId, reply = rednet.receive("factory_net", 3)
    return reply and reply.status == "OK"
end

function requestTurtleClear()
    rednet.broadcast({ command = "CLEAR_ALL" }, "factory_net")
    rednet.receive("factory_net", 2)
end

----------------------------------------------------
-- Скан устройств Create
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

----------------------------------------------------
-- ЭТАП 1: СКАН ИНГРЕДИЕНТОВ
----------------------------------------------------
function scanIngredientsStep()
    pendingIngredients = {}
    pendingDeviceType = "UNKNOWN"

    -- 1. Черепашка
    local turtleGrid = requestTurtleScan()
    if turtleGrid and next(turtleGrid) then
        pendingDeviceType = "TURTLE"
        for slot, item in pairs(turtleGrid) do
            table.insert(pendingIngredients, { slot = slot, name = item.name, count = item.count })
        end
    else
        -- 2. Deployer и Депо
        local handItem = safeGetDeviceItem(devices.deployer)
        local depotArmItem = safeGetDeviceItem(devices.depotArm)
        
        if handItem or depotArmItem then
            pendingDeviceType = "DEPLOYER"
            if handItem then table.insert(pendingIngredients, { role = "hand", name = handItem.name, count = handItem.count }) end
            if depotArmItem then table.insert(pendingIngredients, { role = "depot", name = depotArmItem.name, count = depotArmItem.count }) end
        else
            -- 3. Депо Пресса
            local pressItem = safeGetDeviceItem(devices.depotPress)
            if pressItem then
                pendingDeviceType = "PRESS"
                table.insert(pendingIngredients, { role = "press_depot", name = pressItem.name, count = pressItem.count })
            else
                -- 4. Чаша
                local mixerItem = safeGetDeviceItem(devices.basinMixer) or safeGetDeviceItem(devices.basinPress)
                if mixerItem then
                    pendingDeviceType = "MIXER"
                    table.insert(pendingIngredients, { role = "basin", name = mixerItem.name, count = mixerItem.count })
                end
            end
        end
    end

    if #pendingIngredients == 0 then
        print("[SCAN 1] No input items found!")
        return false
    end

    scanStep = 2 -- Переходим ко 2 этапу (Считали входы, ждем переработки)
    return true
end

----------------------------------------------------
-- ЭТАП 2: СКАН РЕЗУЛЬТАТА И СОХРАНЕНИЕ
----------------------------------------------------
function scanResultAndSaveStep()
    local outputItem = nil

    if pendingDeviceType == "TURTLE" then
        outputItem = pendingIngredients[1] -- Для черепашки результат берется по схеме
    elseif pendingDeviceType == "DEPLOYER" then
        outputItem = safeGetDeviceItem(devices.depotArm)
    elseif pendingDeviceType == "PRESS" then
        outputItem = safeGetDeviceItem(devices.depotPress)
    elseif pendingDeviceType == "MIXER" then
        outputItem = safeGetDeviceItem(devices.basinMixer) or safeGetDeviceItem(devices.basinPress)
    end

    local resultName = outputItem and outputItem.name:gsub(".*:", "") or "Crafted_Item"

    local newRecipe = {
        name = "Recipe #" .. (#recipes + 1),
        device = pendingDeviceType,
        rpm = pendingRpm,
        motorOn = pendingMotorState,
        output = resultName,
        yield = outputItem and outputItem.count or 1,
        ingredients = pendingIngredients
    }

    table.insert(recipes, newRecipe)
    selectedRecipeIdx = #recipes
    saveRecipes()

    if pendingDeviceType == "TURTLE" then
        requestTurtleCraft(1)
        sleep(0.5)
        requestTurtleClear()
    end

    pendingIngredients = {}
    scanStep = 1
    currentPage = "MAIN"
    return true
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
            drawText(t, 2, 1, "=== AUTO-FACTORY CONTROLLER v24 ===", colors.yellow, colors.black)
            local statusStr = motorEnabled and (currentMotorSpeed .. " RPM") or "OFF"
            drawText(t, w - 12, 1, statusStr, motorEnabled and colors.lime or colors.red, colors.black)

            if #recipes == 0 then
                drawText(t, 2, 3, "No recipes. Click [+RECIPE] to start.", colors.red, colors.black)
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

            -- Выбор количества (-64, -30, -10, -1, amount, +1, +10, +30, +64)
            drawBox(t, 2, h - 5, w - 4, 3, colors.gray)
            
            drawBox(t, 3, h - 4, 3, 1, colors.red)
            drawText(t, 3, h - 4, "-64", colors.white, colors.red)

            drawBox(t, 7, h - 4, 3, 1, colors.red)
            drawText(t, 7, h - 4, "-30", colors.white, colors.red)

            drawBox(t, 11, h - 4, 3, 1, colors.orange)
            drawText(t, 11, h - 4, "-10", colors.white, colors.orange)

            drawBox(t, 15, h - 4, 2, 1, colors.orange)
            drawText(t, 15, h - 4, "-1", colors.white, colors.orange)

            drawBox(t, 18, h - 4, 7, 1, colors.black)
            drawText(t, 19, h - 4, string.format("%3d", orderAmount), colors.yellow, colors.black)

            drawBox(t, 26, h - 4, 2, 1, colors.lime)
            drawText(t, 26, h - 4, "+1", colors.black, colors.lime)

            drawBox(t, 29, h - 4, 3, 1, colors.lime)
            drawText(t, 29, h - 4, "+10", colors.black, colors.lime)

            drawBox(t, 33, h - 4, 3, 1, colors.green)
            drawText(t, 33, h - 4, "+30", colors.black, colors.green)

            drawBox(t, 37, h - 4, 3, 1, colors.green)
            drawText(t, 37, h - 4, "+64", colors.black, colors.green)

            -- Кнопка переключения мотора
            local mBtnCol = motorEnabled and colors.lime or colors.red
            drawBox(t, 41, h - 4, 4, 1, mBtnCol)
            drawText(t, 41, h - 4, motorEnabled and "ON" or "OFF", colors.black, mBtnCol)

            -- Кнопки действий
            drawBox(t, 46, h - 4, 5, 1, colors.cyan)
            drawText(t, 46, h - 4, "CRAFT", colors.black, colors.cyan)

            drawBox(t, 52, h - 4, 4, 1, colors.red)
            drawText(t, 52, h - 4, "DEL", colors.white, colors.red)

            local btnY = h - 1
            drawBox(t, 2, btnY, 14, 1, colors.purple)
            drawText(t, 3, btnY, "[ +RECIPE ]", colors.white, colors.purple)

            drawBox(t, 18, btnY, 14, 1, colors.blue)
            drawText(t, 20, btnY, "[ REFRESH ]", colors.white, colors.blue)

        elseif currentPage == "SET_RPM" then
            drawText(t, 2, 1, "=== TWO-STEP RECIPE CREATION ===", colors.yellow, colors.black)

            -- Выбор скорости мотора
            drawText(t, 2, 3, "Motor Speed Control:", colors.white, colors.black)

            local offCol = not pendingMotorState and colors.red or colors.gray
            drawBox(t, 4, 4, 6, 1, offCol)
            drawText(t, 5, 4, "[OFF]", colors.white, offCol)

            local rpm64Col = (pendingMotorState and pendingRpm == 64) and colors.lime or colors.cyan
            drawBox(t, 11, 4, 7, 1, rpm64Col)
            drawText(t, 12, 4, "64 RPM", colors.black, rpm64Col)

            local rpm128Col = (pendingMotorState and pendingRpm == 128) and colors.lime or colors.blue
            drawBox(t, 19, 4, 8, 1, rpm128Col)
            drawText(t, 20, 4, "128 RPM", colors.white, rpm128Col)

            local rpm256Col = (pendingMotorState and pendingRpm == 256) and colors.lime or colors.purple
            drawBox(t, 28, 4, 8, 1, rpm256Col)
            drawText(t, 29, 4, "256 RPM", colors.white, rpm256Col)

            -- Двухэтапные кнопки сканирования
            if scanStep == 1 then
                drawText(t, 2, 7, "Step 1: Put raw ingredients on machine", colors.yellow, colors.black)
                drawBox(t, 4, 9, 22, 1, colors.green)
                drawText(t, 5, 9, "[ 1. SCAN INGREDIENTS ]", colors.black, colors.green)
            else
                drawText(t, 2, 7, "Step 2: Turn Motor ON & wait for craft", colors.yellow, colors.black)
                drawText(t, 2, 8, "Inputs detected: " .. #pendingIngredients .. " items", colors.lime, colors.black)
                drawBox(t, 4, 10, 24, 1, colors.lime)
                drawText(t, 5, 10, "[ 2. SCAN RESULT & SAVE ]", colors.black, colors.lime)
            end

            local btnY = h - 1
            drawBox(t, 2, btnY, 14, 1, colors.red)
            drawText(t, 5, btnY, "[ CANCEL ]", colors.white, colors.red)
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
                if x >= 3 and x <= 5 then
                    orderAmount = math.max(1, orderAmount - 64)
                    renderUI()
                elseif x >= 7 and x <= 9 then
                    orderAmount = math.max(1, orderAmount - 30)
                    renderUI()
                elseif x >= 11 and x <= 13 then
                    orderAmount = math.max(1, orderAmount - 10)
                    renderUI()
                elseif x >= 15 and x <= 16 then
                    orderAmount = math.max(1, orderAmount - 1)
                    renderUI()
                elseif x >= 26 and x <= 27 then
                    orderAmount = orderAmount + 1
                    renderUI()
                elseif x >= 29 and x <= 31 then
                    orderAmount = orderAmount + 10
                    renderUI()
                elseif x >= 33 and x <= 35 then
                    orderAmount = orderAmount + 30
                    renderUI()
                elseif x >= 37 and x <= 39 then
                    orderAmount = orderAmount + 64
                    renderUI()
                elseif x >= 41 and x <= 44 then
                    motorEnabled = not motorEnabled
                    applyMotorState(currentMotorSpeed, motorEnabled)
                    renderUI()
                elseif x >= 46 and x <= 50 and #recipes > 0 then
                    local selR = recipes[selectedRecipeIdx]
                    if selR then
                        applyMotorState(selR.rpm or 256, selR.motorOn)
                        if selR.device == "TURTLE" then
                            requestTurtleCraft(orderAmount)
                        end
                    end
                    renderUI()
                elseif x >= 52 and x <= 55 and #recipes > 0 then
                    table.remove(recipes, selectedRecipeIdx)
                    if selectedRecipeIdx > #recipes then selectedRecipeIdx = math.max(1, #recipes) end
                    saveRecipes()
                    renderUI()
                end

            elseif y >= h - 1 then
                if x >= 2 and x <= 16 then
                    currentPage = "SET_RPM"
                    scanStep = 1
                    pendingRpm = currentMotorSpeed
                    pendingMotorState = motorEnabled
                    renderUI()
                end
            end

        elseif currentPage == "SET_RPM" then
            if y == 4 then
                if x >= 4 and x <= 9 then
                    pendingMotorState = false
                    applyMotorState(pendingRpm, false)
                    renderUI()
                elseif x >= 11 and x <= 17 then
                    pendingMotorState = true
                    pendingRpm = 64
                    applyMotorState(64, true)
                    renderUI()
                elseif x >= 19 and x <= 26 then
                    pendingMotorState = true
                    pendingRpm = 128
                    applyMotorState(128, true)
                    renderUI()
                elseif x >= 28 and x <= 35 then
                    pendingMotorState = true
                    pendingRpm = 256
                    applyMotorState(256, true)
                    renderUI()
                end
            elseif y == 9 and scanStep == 1 and x >= 4 and x <= 25 then
                scanIngredientsStep()
                renderUI()
            elseif y == 10 and scanStep == 2 and x >= 4 and x <= 28 then
                scanResultAndSaveStep()
                renderUI()
            elseif y >= h - 1 and x >= 2 and x <= 16 then
                currentPage = "MAIN"
                scanStep = 1
                pendingIngredients = {}
                renderUI()
            end
        end
    end
end
