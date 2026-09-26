-- Master Factory Controller v22.0
-- Fixed CANCEL button, Added Stack-based Craft Amount, Motor ON/OFF Toggle, Recursive Crafting Logic

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
-- Управление Мотором
----------------------------------------------------
function setMotorSpeed(speed, enabled)
    currentMotorSpeed = speed
    if enabled ~= nil then motorEnabled = enabled end
    
    if peripheral.isPresent(devices.motor) then
        local ok, m = pcall(peripheral.wrap, devices.motor)
        if ok and m and m.setSpeed then
            local targetSpeed = motorEnabled and currentMotorSpeed or 0
            pcall(m.setSpeed, targetSpeed)
            print("Motor 5 RPM updated to: " .. targetSpeed)
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
-- Безопасный скан периферии Create
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
-- Рекурсивная проверка ингредиентов в Силосах
----------------------------------------------------
function getSiloItemCount(itemName)
    local total = 0
    for _, siloName in ipairs(silos) do
        if peripheral.isPresent(siloName) then
            local ok, silo = pcall(peripheral.wrap, siloName)
            if ok and silo and silo.list then
                local list = silo.list()
                for _, item in pairs(list) do
                    if item.name == itemName then
                        total = total + item.count
                    end
                end
            end
        end
    end
    return total
end

function checkAndCraftRecursive(recipe, reqAmount)
    for _, ing in ipairs(recipe.ingredients or {}) do
        local needed = ing.count * reqAmount
        local inStock = getSiloItemCount(ing.name)
        
        if inStock < needed then
            local missing = needed - inStock
            print("Missing " .. missing .. "x " .. ing.name .. ". Checking sub-recipes...")
            
            -- Ищем рецепт для создания недостающего компонента
            local subRecipe = nil
            for _, r in ipairs(recipes) do
                if r.output == ing.name:gsub(".*:", "") then
                    subRecipe = r
                    break
                end
            end
            
            if subRecipe then
                print("Found sub-recipe for " .. ing.name .. ". Executing sub-craft...")
                checkAndCraftRecursive(subRecipe, missing)
            else
                print("Warning: No recipe found for sub-component " .. ing.name)
            end
        end
    end
end

----------------------------------------------------
-- АВТОМАТИЧЕСКИЙ СКАН УСТРОЙСТВ
----------------------------------------------------
function startAutoScanAll()
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
        print("No items detected on any machine!")
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
        rpm = pendingRpm,
        motorOn = pendingMotorState,
        output = mainName,
        yield = 1,
        ingredients = pendingIngredients
    }

    table.insert(recipes, newRecipe)
    saveRecipes()

    if pendingDeviceType == "TURTLE" then
        requestTurtleCraft(1)
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
            drawText(t, 2, 1, "=== AUTO-FACTORY CONTROLLER v22 ===", colors.yellow, colors.black)
            local statusStr = motorEnabled and (currentMotorSpeed .. " RPM") or "OFF"
            drawText(t, w - 12, 1, statusStr, motorEnabled and colors.lime or colors.red, colors.black)

            if #recipes == 0 then
                drawText(t, 2, 3, "No recipes registered. Click [+RECIPE] to add.", colors.red, colors.black)
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

            -- Панель количества (-64, -1, [Amount], +1, +64)
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

            -- Кнопки действий
            drawBox(t, 34, h - 4, 8, 1, colors.cyan)
            drawText(t, 35, h - 4, "[CRAFT]", colors.black, colors.cyan)

            drawBox(t, 43, h - 4, 6, 1, colors.red)
            drawText(t, 44, h - 4, "[DEL]", colors.white, colors.red)

            local btnY = h - 1
            drawBox(t, 2, btnY, 14, 1, colors.purple)
            drawText(t, 3, btnY, "[ +RECIPE ]", colors.white, colors.purple)

            drawBox(t, 18, btnY, 14, 1, colors.blue)
            drawText(t, 20, btnY, "[ REFRESH ]", colors.white, colors.blue)

        elseif currentPage == "SET_RPM" then
            drawText(t, 2, 1, "=== RECIPE SETUP: MOTOR & SCAN ===", colors.yellow, colors.black)
            drawText(t, 2, 3, "1. Configure Motor State & Speed:", colors.white, colors.black)

            -- Переключатель ВКЛ / ВЫКЛ Мотора
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

            drawText(t, 2, 8, "2. Click SCAN NOW when ingredients are placed:", colors.white, colors.black)
            drawBox(t, 4, 10, 16, 1, colors.green)
            drawText(t, 6, 10, "[ SCAN NOW ]", colors.black, colors.green)

            local btnY = h - 1
            drawBox(t, 2, btnY, 14, 1, colors.red)
            drawText(t, 4, btnY, "[ CANCEL ]", colors.white, colors.red)

        elseif currentPage == "CONFIRM" then
            drawText(t, 2, 1, "=== CONFIRM DETECTED RECIPE ===", colors.yellow, colors.black)
            local stateText = pendingMotorState and (pendingRpm .. " RPM") or "OFF"
            drawText(t, 2, 3, "Machine: " .. pendingDeviceType .. " | Motor: " .. stateText, colors.cyan, colors.black)

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
                elseif x >= 34 and x <= 41 and #recipes > 0 then
                    local selR = recipes[selectedRecipeIdx]
                    if selR then
                        setMotorSpeed(selR.rpm or 256, selR.motorOn)
                        checkAndCraftRecursive(selR, orderAmount)
                        if selR.device == "TURTLE" then
                            requestTurtleCraft(orderAmount)
                        end
                    end
                    renderUI()
                elseif x >= 43 and x <= 48 and #recipes > 0 then
                    table.remove(recipes, selectedRecipeIdx)
                    if selectedRecipeIdx > #recipes then selectedRecipeIdx = math.max(1, #recipes) end
                    saveRecipes()
                    renderUI()
                end

            elseif y >= h - 1 then
                if x >= 2 and x <= 16 then
                    currentPage = "SET_RPM"
                    pendingRpm = 256
                    pendingMotorState = true
                    renderUI()
                end
            end

        elseif currentPage == "SET_RPM" then
            if y == 5 then
                if x >= 4 and x <= 10 then
                    pendingMotorState = false
                    setMotorSpeed(0, false)
                    renderUI()
                elseif x >= 12 and x <= 19 then
                    pendingMotorState = true
                    pendingRpm = 64
                    setMotorSpeed(64, true)
                    renderUI()
                elseif x >= 21 and x <= 29 then
                    pendingMotorState = true
                    pendingRpm = 128
                    setMotorSpeed(128, true)
                    renderUI()
                elseif x >= 31 and x <= 39 then
                    pendingMotorState = true
                    pendingRpm = 256
                    setMotorSpeed(256, true)
                    renderUI()
                end
            elseif y == 10 and x >= 4 and x <= 20 then
                startAutoScanAll()
                renderUI()
            elseif y >= h - 1 and x >= 2 and x <= 16 then
                currentPage = "MAIN"
                pendingIngredients = {}
                renderUI()
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
