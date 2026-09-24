-- Master Factory Controller v10.0
-- Full Integration with Item Silos & Rednet Turtle Agent

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
    turtle     = "turtle_21"
}

local motorName = nil
for _, name in ipairs(peripheral.getNames()) do
    if name:find("electric_motor") or peripheral.getType(name) == "create:electric_motor" then
        motorName = name
        break
    end
end

local recipes = {}
local currentPage = "MAIN" -- "MAIN", "RECORD"
local selectedRecipeIdx = 1
local orderAmount = 1

----------------------------------------------------
-- Загрузка и Сохранение
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
-- Сетевой обмен с Черепашкой
----------------------------------------------------
function requestTurtleScan()
    rednet.broadcast({ command = "SCAN" }, "factory_net")
    local senderId, reply = rednet.receive("factory_net", 2)
    if reply and reply.grid then
        return reply.grid
    end
    return nil
end

function requestTurtleCraft()
    rednet.broadcast({ command = "CRAFT" }, "factory_net")
    local senderId, reply = rednet.receive("factory_net", 3)
    return reply and reply.status == "OK"
end

----------------------------------------------------
-- Перемещение предметов по проводам (Silos)
----------------------------------------------------
function setMotorSpeed(speed)
    if motorName and peripheral.isPresent(motorName) then
        local m = peripheral.wrap(motorName)
        if m and m.setSpeed then m.setSpeed(speed) end
    end
end

function pullFromSiloToDevice(itemName, count, targetDevice, targetSlot)
    local remaining = count
    for _, siloName in ipairs(silos) do
        if peripheral.isPresent(siloName) and peripheral.isPresent(targetDevice) then
            local silo = peripheral.wrap(siloName)
            local items = silo.list()
            for slot, item in pairs(items) do
                if item.name == itemName then
                    local moved = silo.pushItems(targetDevice, slot, remaining, targetSlot)
                    remaining = remaining - moved
                    if remaining <= 0 then return true end
                end
            end
        end
    end
    return remaining < count
end

function pushDeviceToSilo(sourceDevice, slot)
    if not peripheral.isPresent(sourceDevice) then return false end
    local src = peripheral.wrap(sourceDevice)
    for _, siloName in ipairs(silos) do
        if peripheral.isPresent(siloName) then
            local moved = src.pushItems(siloName, slot)
            if moved > 0 then return true end
        end
    end
    return false
end

----------------------------------------------------
-- Ручное сканирование рецепта
----------------------------------------------------
function scanCurrentRecipe()
    print("Requesting inventory scan from Turtle...")
    local grid = requestTurtleScan()
    
    if not grid then
        print("Error: Turtle 21 not responding via Rednet!")
        return false
    end

    local ingredients = {}
    local mainOutput = "Unknown Output"

    for slot, item in pairs(grid) do
        table.insert(ingredients, {
            slot = slot,
            name = item.name,
            count = item.count
        })
        mainOutput = item.name .. "_crafted"
    end

    if #ingredients > 0 then
        table.insert(recipes, {
            name = "Recipe #" .. (#recipes + 1),
            output = mainOutput,
            ingredients = ingredients
        })
        saveRecipes()
        print("Recipe successfully recorded!")
        return true
    else
        print("No items detected in Turtle grid!")
        return false
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
            drawText(t, 2, 1, "=== AUTO-FACTORY CONTROLLER ===", colors.yellow, colors.black)

            if #recipes == 0 then
                drawText(t, 2, 3, "No recipes registered. Click [+RECIPE] to add.", colors.red, colors.black)
            else
                for i, r in ipairs(recipes) do
                    if i <= 5 then
                        local isSel = (i == selectedRecipeIdx)
                        local prefix = isSel and "> " or "  "
                        local bgCol = isSel and colors.gray or colors.black
                        local fgCol = isSel and colors.white or colors.cyan
                        
                        drawBox(t, 2, 2 + i, w - 4, 1, bgCol)
                        drawText(t, 2, 2 + i, prefix .. i .. ". " .. (r.output or "Item"), fgCol, bgCol)
                    end
                end

                local selR = recipes[selectedRecipeIdx]
                if selR and selR.ingredients then
                    local ingText = "Inputs: "
                    for _, ing in ipairs(selR.ingredients) do
                        ingText = ingText .. ing.count .. "x " .. ing.name:gsub(".*:", "") .. " "
                    end
                    drawText(t, 2, 8, ingText:sub(1, w - 4), colors.lightGray, colors.black)
                end
            end

            -- Панель управления
            drawBox(t, 2, h - 5, w - 4, 3, colors.gray)
            drawText(t, 3, h - 4, "Qty:", colors.white, colors.gray)

            drawBox(t, 8, h - 4, 3, 1, colors.red)
            drawText(t, 9, h - 4, "-", colors.white, colors.red)

            drawText(t, 12, h - 4, string.format("%2d", orderAmount), colors.yellow, colors.gray)

            drawBox(t, 15, h - 4, 3, 1, colors.green)
            drawText(t, 16, h - 4, "+", colors.white, colors.green)

            drawBox(t, 20, h - 4, 11, 1, colors.lime)
            drawText(t, 21, h - 4, "[ START ]", colors.black, colors.lime)

            drawBox(t, 32, h - 4, 12, 1, colors.red)
            drawText(t, 33, h - 4, "[ DELETE ]", colors.white, colors.red)

            -- Нижняя панель
            local btnY = h - 1
            drawBox(t, 2, btnY, 14, 1, colors.purple)
            drawText(t, 3, btnY, "[ +RECIPE ]", colors.white, colors.purple)

            drawBox(t, 18, btnY, 14, 1, colors.blue)
            drawText(t, 20, btnY, "[ REFRESH ]", colors.white, colors.blue)

        elseif currentPage == "RECORD" then
            drawText(t, 2, 1, "=== RECORDER MODE ===", colors.red, colors.black)
            drawText(t, 2, 3, "1. Place items in Turtle 21 inventory.", colors.yellow, colors.black)
            drawText(t, 2, 4, "2. Press [ SCAN NOW ] button below.", colors.white, colors.black)

            local btnY = h - 1
            drawBox(t, 2, btnY, 14, 1, colors.green)
            drawText(t, 3, btnY, "[ SCAN NOW ]", colors.black, colors.green)

            drawBox(t, 18, btnY, 14, 1, colors.red)
            drawText(t, 20, btnY, "[ CANCEL ]", colors.white, colors.red)
        end
    end
end

----------------------------------------------------
-- Выполнение Крафта
----------------------------------------------------
function executeCraft(recipe, count)
    setMotorSpeed(256)
    print("Pulling ingredients from Item Silos...")

    if recipe.ingredients then
        for _, ing in ipairs(recipe.ingredients) do
            pullFromSiloToDevice(ing.name, ing.count * count, devices.turtle, ing.slot)
        end
    end

    print("Executing craft command via Rednet...")
    requestTurtleCraft()
    sleep(0.5)

    print("Returning finished products to Item Silos...")
    for slot = 1, 16 do
        pushDeviceToSilo(devices.turtle, slot)
    end
    print("Crafting cycle finished!")
end

----------------------------------------------------
-- Обработка событий
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
                if x >= 8 and x <= 10 and orderAmount > 1 then
                    orderAmount = orderAmount - 1
                    renderUI()
                elseif x >= 15 and x <= 17 then
                    orderAmount = orderAmount + 1
                    renderUI()
                elseif x >= 20 and x <= 30 and #recipes > 0 then
                    executeCraft(recipes[selectedRecipeIdx], orderAmount)
                    renderUI()
                elseif x >= 32 and x <= 43 and #recipes > 0 then
                    table.remove(recipes, selectedRecipeIdx)
                    if selectedRecipeIdx > #recipes then selectedRecipeIdx = math.max(1, #recipes) end
                    saveRecipes()
                    renderUI()
                end

            elseif y >= h - 1 then
                if x >= 2 and x <= 16 then
                    currentPage = "RECORD"
                    setMotorSpeed(0)
                    renderUI()
                elseif x >= 18 and x <= 32 then
                    renderUI()
                end
            end

        elseif currentPage == "RECORD" then
            if y >= h - 1 then
                if x >= 2 and x <= 16 then
                    if scanCurrentRecipe() then
                        currentPage = "MAIN"
                    end
                    renderUI()
                elseif x >= 18 and x <= 32 then
                    currentPage = "MAIN"
                    renderUI()
                end
            end
        end
    end
end
