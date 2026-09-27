-- Master Factory Controller v23.0
-- Dynamic Live Motor Control + Auto-Craft Trigger on Scan + Fixed Motor Freeze

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
local currentPage = "MAIN" -- "MAIN", "SET_RPM", "CONFIRM"
local selectedRecipeIdx = 1
local orderAmount = 1

local currentMotorSpeed = 256
local motorEnabled = true

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
-- Физическое управление Мотором
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
-- АВТОМАТИЧЕСКИЙ СКАН И ЗАПУСК КРАФТА
----------------------------------------------------
function startAutoScanAndCraft()
    pendingIngredients = {}
    pendingDeviceType = "UNKNOWN"

    -- 1. Сканируем Черепашку
    local turtleGrid = requestTurtleScan()
    if turtleGrid and next(turtleGrid) then
        pendingDeviceType = "TURTLE"
        for slot, item in pairs(turtleGrid) do
            table.insert(pendingIngredients, { slot = slot, name = item.name, count = item.count })
        end
    else
        -- 2. Сканируем Руку и Депо
        local handItem = safeGetDeviceItem(devices.deployer)
        local depotArmItem = safeGetDeviceItem(devices.depotArm)
        
        if handItem or depotArmItem then
            pendingDeviceType = "DEPLOYER"
            if handItem then table.insert(pendingIngredients, { role = "hand", name = handItem.name, count = handItem.count }) end
            if depotArmItem then table.insert(pendingIngredients, { role = "depot", name = depotArmItem.name, count = depotArmItem.count }) end
        else
            -- 3. Сканируем Депо Пресса
            local pressItem = safeGetDeviceItem(devices.depotPress)
            if pressItem then
                pendingDeviceType = "PRESS"
                table.insert(pendingIngredients, { role = "press_depot", name = pressItem.name, count = pressItem.count })
            else
                -- 4. Сканируем Чашу
                local mixerItem = safeGetDeviceItem(devices.basinMixer) or safeGetDeviceItem(devices.basinPress)
                if mixerItem then
                    pendingDeviceType = "MIXER"
                    table.insert(pendingIngredients, { role = "basin", name = mixerItem.name, count = mixerItem.count })
                end
            end
        end
    end

    if #pendingIngredients == 0 then
        print("[SCAN] Items not found on any device!")
        return false
    end

    -- Сохраняем рецепт
    local mainName = pendingIngredients[1] and pendingIngredients[1].name:gsub(".*:", "") or "Crafted_Item"
    local newRecipe = {
        name = "Recipe #" .. (#recipes + 1),
        device = pendingDeviceType,
        rpm = pendingRpm,
        motorOn = pendingMotorState,
        output = mainName,
        yield = 1,
        ingredients = pendingIngredients
    }

    table.insert(recipes, newRecipe)
    selectedRecipeIdx = #recipes
    saveRecipes()

    -- Автоматический запуск мотора и первого крафта
    applyMotorState(pendingRpm, pendingMotorState)

    if pendingDeviceType == "TURTLE" then
        requestTurtleCraft(1)
        sleep(0.5)
        requestTurtleClear()
    end

    pendingIngredients = {}
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
            drawText(t, 2, 1, "=== AUTO-FACTORY CONTROLLER v23 ===", colors.yellow, colors.black)
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

            -- Выбор количества (-64, -1, amount, +1, +64)
            drawBox(t, 2, h - 5, w - 4, 3, colors.gray)
            
            drawBox(t, 3, h - 4, 4, 1, colors.red)
            drawText(t, 3, h - 4, "-64", colors.white, colors.red)

            drawBox(t, 8, h - 4, 3, 1, colors.orange)
            drawText(t, 9, h - 4, "-", colors.white, colors.orange)

            drawBox(t, 12, h - 4, 9, 1, colors.black)
            drawText(t, 13, h - 4, string.format("%4d pcs", orderAmount), colors.yellow, colors.black)

            drawBox(t, 22, h - 4, 3, 1, colors.lime)
            drawText(t, 23, h - 4, "+", colors.black, colors.lime)

            drawBox(t, 26, h - 4, 4, 1, colors.green)
            drawText(t, 26, h - 4, "+64", colors.black, colors.green)

            -- Кнопка управления мотором (Вкл/Выкл вручную прямо с главного экрана)
            local mBtnCol = motorEnabled and colors.lime or colors.red
            drawBox(t, 32, h - 4, 7, 1, mBtnCol)
            drawText(t, 33, h - 4, motorEnabled and "[ON]" or "[OFF]", colors.black, mBtnCol)

            -- Кнопки действий
            drawBox(t, 40, h - 4, 8, 1, colors.cyan)
            drawText(t, 41, h - 4, "[CRAFT]", colors.black, colors.cyan)

            drawBox(t, 49, h - 4, 6, 1, colors.red)
            drawText(t, 50, h - 4, "[DEL]", colors.white, colors.red)

            local btnY = h - 1
            drawBox(t, 2, btnY, 14, 1, colors.purple)
            drawText(t, 3, btnY, "[ +RECIPE ]", colors.white, colors.purple)

            drawBox(t, 18, btnY, 14, 1, colors.blue)
            drawText(t, 20, btnY, "[ REFRESH ]", colors.white, colors.blue)

        elseif currentPage == "SET_RPM" then
            drawText(t, 2, 1, "=== RECIPE SETUP: MOTOR & SCAN ===", colors.yellow, colors.black)
            drawText(t, 2, 3, "1. Live Motor Control (Toggle speed now):", colors.white, colors.black)

            -- Переключатели Мотора
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

            drawText(t, 2, 8, "2. Scan items & start craft instantly:", colors.white, colors.black)
            drawBox(t, 4, 10, 18, 1, colors.green)
            drawText(t, 6, 10, "[ SCAN & CRAFT ]", colors.black, colors.green)

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
                if x >= 3 and x <= 6 then
                    orderAmount = math.max(1, orderAmount - 64)
                    renderUI()
                elseif x >= 8 and x <= 10 then
                    orderAmount = math.max(1, orderAmount - 1)
                    renderUI()
                elseif x >= 22 and x <= 24 then
                    orderAmount = orderAmount + 1
                    renderUI()
                elseif x >= 26 and x <= 29 then
                    orderAmount = orderAmount + 64
                    renderUI()
                elseif x >= 32 and x <= 38 then
                    -- Ручное переключение мотора ВКЛ/ВЫКЛ на главном экране
                    motorEnabled = not motorEnabled
                    applyMotorState(currentMotorSpeed, motorEnabled)
                    renderUI()
                elseif x >= 40 and x <= 47 and #recipes > 0 then
                    local selR = recipes[selectedRecipeIdx]
                    if selR then
                        applyMotorState(selR.rpm or 256, selR.motorOn)
                        if selR.device == "TURTLE" then
                            requestTurtleCraft(orderAmount)
                        end
                    end
                    renderUI()
                elseif x >= 49 and x <= 55 and #recipes > 0 then
                    table.remove(recipes, selectedRecipeIdx)
                    if selectedRecipeIdx > #recipes then selectedRecipeIdx = math.max(1, #recipes) end
                    saveRecipes()
                    renderUI()
                end

            elseif y >= h - 1 then
                if x >= 2 and x <= 16 then
                    currentPage = "SET_RPM"
                    pendingRpm = currentMotorSpeed
                    pendingMotorState = motorEnabled
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
            elseif y == 10 and x >= 4 and x <= 22 then
                startAutoScanAndCraft()
                renderUI()
            elseif y >= h - 1 and x >= 2 and x <= 18 then
                -- CANCEL
                currentPage = "MAIN"
                pendingIngredients = {}
                renderUI()
            end
        end
    end
end
