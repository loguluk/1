-- Master Factory Controller v20.0
-- Fixed Line 115/119 nil-errors, Auto Device Detection & Motor Speed Buttons

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
local currentPage = "MAIN" -- "MAIN", "RECORD", "CONFIRM"
local selectedRecipeIdx = 1
local orderAmount = 1
local currentMotorSpeed = 256

local pendingIngredients = {}
local pendingDeviceType = "TURTLE"
local detectedOutputItem = "Unknown"

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
-- Управление Мотором (electric_motor_5)
----------------------------------------------------
function setMotorSpeed(speed)
    currentMotorSpeed = speed
    if peripheral.isPresent(devices.motor) then
        local ok, m = pcall(peripheral.wrap, devices.motor)
        if ok and m and m.setSpeed then
            pcall(m.setSpeed, speed)
            print("Motor 5 RPM updated to: " .. speed)
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

function requestTurtleCraft()
    rednet.broadcast({ command = "CRAFT" }, "factory_net")
    local senderId, reply = rednet.receive("factory_net", 3)
    return reply and reply.status == "OK"
end

function requestTurtleClear()
    rednet.broadcast({ command = "CLEAR_ALL" }, "factory_net")
    rednet.receive("factory_net", 2)
end

----------------------------------------------------
-- Безопасный скан периферии Create (Без ошибок nil)
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
-- АВТОМАТИЧЕСКОЕ СКАНИРОВАНИЕ ВСЕХ МЕХАНИЗМОВ
----------------------------------------------------
function startAutoScanAll()
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
        -- 2. Сканируем Руку (Deployer) и её Депо
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
                -- 4. Сканируем Чашу Миксера
                local mixerItem = safeGetDeviceItem(devices.basinMixer) or safeGetDeviceItem(devices.basinPress)
                if mixerItem then
                    pendingDeviceType = "MIXER"
                    table.insert(pendingIngredients, { role = "basin", name = mixerItem.name, count = mixerItem.count })
                end
            end
        end
    end

    if #pendingIngredients == 0 then
        print("No items found on any machine!")
        return false
    end

    currentPage = "CONFIRM"
    return true
end

function confirmAndSaveRecipe()
    local mainName = pendingIngredients[1] and pendingIngredients[1].name:gsub(".*:", "") or "Crafted_Item"
    local newRecipe = {
        name = "Recipe #" .. (#recipes + 1),
        device = pendingDeviceType,
        output = mainName,
        yield = 1,
        ingredients = pendingIngredients
    }

    table.insert(recipes, newRecipe)
    saveRecipes()

    if pendingDeviceType == "TURTLE" then
        requestTurtleCraft()
        sleep(0.5)
        requestTurtleClear()
    end

    pendingIngredients = {}
    currentPage = "MAIN"
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
            drawText(t, 2, 1, "=== AUTO-FACTORY CONTROLLER v20 ===", colors.yellow, colors.black)
            drawText(t, w - 12, 1, currentMotorSpeed .. " RPM", colors.lime, colors.black)

            if #recipes == 0 then
                drawText(t, 2, 3, "No recipes registered. Click [+RECIPE] to scan.", colors.red, colors.black)
            else
                for i, r in ipairs(recipes) do
                    if i <= 5 then
                        local isSel = (i == selectedRecipeIdx)
                        local prefix = isSel and "> " or "  "
                        local bgCol = isSel and colors.gray or colors.black
                        local fgCol = isSel and colors.white or colors.cyan
                        local devTag = " [" .. (r.device or "TURTLE") .. "]"
                        
                        drawBox(t, 2, 2 + i, w - 4, 1, bgCol)
                        drawText(t, 2, 2 + i, prefix .. i .. ". " .. (r.output or "Item") .. devTag, fgCol, bgCol)
                    end
                end
            end

            -- Панель количества и скорости мотора
            drawBox(t, 2, h - 5, w - 4, 3, colors.gray)
            
            drawBox(t, 3, h - 4, 3, 1, colors.red)
            drawText(t, 4, h - 4, "-", colors.white, colors.red)

            drawBox(t, 7, h - 4, 7, 1, colors.black)
            drawText(t, 8, h - 4, string.format("%3d pcs", orderAmount), colors.yellow, colors.black)

            drawBox(t, 15, h - 4, 3, 1, colors.green)
            drawText(t, 16, h - 4, "+", colors.white, colors.green)

            -- Кнопки скоростей мотора
            drawBox(t, 19, h - 4, 5, 1, colors.cyan)
            drawText(t, 20, h - 4, "64", colors.black, colors.cyan)

            drawBox(t, 25, h - 4, 5, 1, colors.blue)
            drawText(t, 26, h - 4, "128", colors.white, colors.blue)

            drawBox(t, 31, h - 4, 5, 1, colors.purple)
            drawText(t, 32, h - 4, "256", colors.white, colors.purple)

            drawBox(t, 38, h - 4, 9, 1, colors.lime)
            drawText(t, 39, h - 4, "[CRAFT]", colors.black, colors.lime)

            drawBox(t, 49, h - 4, 7, 1, colors.red)
            drawText(t, 50, h - 4, "[DEL]", colors.white, colors.red)

            local btnY = h - 1
            drawBox(t, 2, btnY, 14, 1, colors.purple)
            drawText(t, 3, btnY, "[ +RECIPE ]", colors.white, colors.purple)

            drawBox(t, 18, btnY, 14, 1, colors.blue)
            drawText(t, 20, btnY, "[ REFRESH ]", colors.white, colors.blue)

        elseif currentPage == "RECORD" then
            drawText(t, 2, 1, "=== AUTOMATIC RECIPE SCAN ===", colors.yellow, colors.black)
            drawText(t, 2, 3, "Place ingredients on ANY machine (Turtle, Press, Hand).", colors.white, colors.black)
            drawText(t, 2, 4, "Click [ SCAN NOW ] to detect automatically.", colors.yellow, colors.black)

            local btnY = h - 1
            drawBox(t, 2, btnY, 14, 1, colors.green)
            drawText(t, 3, btnY, "[ SCAN NOW ]", colors.black, colors.green)

            drawBox(t, 18, btnY, 14, 1, colors.red)
            drawText(t, 20, btnY, "[ CANCEL ]", colors.white, colors.red)

        elseif currentPage == "CONFIRM" then
            drawText(t, 2, 1, "=== CONFIRM RECIPE ===", colors.yellow, colors.black)
            drawText(t, 2, 3, "Detected Machine: " .. pendingDeviceType, colors.cyan, colors.black)

            for i, ing in ipairs(pendingIngredients) do
                if i <= 5 then
                    local label = ing.role and (" Role " .. ing.role .. ": ") or (" Slot " .. (ing.slot or i) .. ": ")
                    drawText(t, 4, 3 + i, label .. ing.count .. "x " .. ing.name:gsub(".*:", ""), colors.lime, colors.black)
                end
            end

            local btnY = h - 1
            drawBox(t, 2, btnY, 18, 1, colors.green)
            drawText(t, 4, btnY, "[ SAVE RECIPE ]", colors.black, colors.green)

            drawBox(t, 22, btnY, 14, 1, colors.red)
            drawText(t, 24, btnY, "[ CANCEL ]", colors.white, colors.red)
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
                if x >= 3 and x <= 5 and orderAmount > 1 then
                    orderAmount = orderAmount - 1
                    renderUI()
                elseif x >= 15 and x <= 17 then
                    orderAmount = orderAmount + 1
                    renderUI()
                -- Переключение скоростей мотора
                elseif x >= 19 and x <= 23 then
                    setMotorSpeed(64)
                    renderUI()
                elseif x >= 25 and x <= 29 then
                    setMotorSpeed(128)
                    renderUI()
                elseif x >= 31 and x <= 35 then
                    setMotorSpeed(256)
                    renderUI()
                elseif x >= 38 and x <= 46 and #recipes > 0 then
                    setMotorSpeed(currentMotorSpeed)
                    if recipes[selectedRecipeIdx].device == "TURTLE" then
                        requestTurtleCraft()
                    end
                    renderUI()
                elseif x >= 49 and x <= 56 and #recipes > 0 then
                    table.remove(recipes, selectedRecipeIdx)
                    if selectedRecipeIdx > #recipes then selectedRecipeIdx = math.max(1, #recipes) end
                    saveRecipes()
                    renderUI()
                end

            elseif y >= h - 1 then
                if x >= 2 and x <= 16 then
                    currentPage = "RECORD"
                    renderUI()
                end
            end

        elseif currentPage == "RECORD" then
            if y >= h - 1 then
                if x >= 2 and x <= 16 then
                    startAutoScanAll()
                    renderUI()
                elseif x >= 18 and x <= 32 then
                    currentPage = "MAIN"
                    renderUI()
                end
            end

        elseif currentPage == "CONFIRM" then
            if y >= h - 1 then
                if x >= 2 and x <= 19 then
                    confirmAndSaveRecipe()
                    renderUI()
                elseif x >= 22 and x <= 35 then
                    pendingIngredients = {}
                    currentPage = "MAIN"
                    renderUI()
                end
            end
        end
    end
end
