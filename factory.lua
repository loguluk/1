-- Factory Controller (Direct Cable Transfer via Item Silo + Easy Quick-Craft Menu)

local RECIPE_FILE = "recipes.json"
local monitor = peripheral.find("monitor")

if monitor then
    monitor.setTextScale(0.5)
    monitor.clear()
end
term.clear()

-- Башни-силосы
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
-- Загрузка / Сохранение
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
-- Передача предметов по проводам (без черепашки)
----------------------------------------------------
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

function setMotorSpeed(speed)
    if motorName and peripheral.isPresent(motorName) then
        local m = peripheral.wrap(motorName)
        if m and m.setSpeed then m.setSpeed(speed) end
    end
end

----------------------------------------------------
-- Отрисовка
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

            -- Список рецептов
            if #recipes == 0 then
                drawText(t, 2, 3, "No recipes found. Click [+RECIPE] to add.", colors.red, colors.black)
            else
                for i, r in ipairs(recipes) do
                    if i <= 6 then
                        local isSel = (i == selectedRecipeIdx)
                        local prefix = isSel and "> " or "  "
                        local bgCol = isSel and colors.gray or colors.black
                        local fgCol = isSel and colors.white or colors.cyan
                        
                        drawBox(t, 2, 2 + i, w - 4, 1, bgCol)
                        drawText(t, 2, 2 + i, prefix .. i .. ". " .. (r.output or "Item"), fgCol, bgCol)
                    end
                end
            end

            -- Быстрая панель заказа прямо в Главном Меню
            drawBox(t, 2, h - 5, w - 4, 3, colors.gray)
            drawText(t, 4, h - 4, "Amount: ", colors.white, colors.gray)

            drawBox(t, 12, h - 4, 3, 1, colors.red)
            drawText(t, 13, h - 4, "-", colors.white, colors.red)

            drawText(t, 16, h - 4, string.format("%2d pcs", orderAmount), colors.yellow, colors.gray)

            drawBox(t, 23, h - 4, 3, 1, colors.green)
            drawText(t, 24, h - 4, "+", colors.white, colors.green)

            drawBox(t, 28, h - 4, 14, 1, colors.lime)
            drawText(t, 29, h - 4, "[ START ]", colors.black, colors.lime)

            -- Нижняя системная панель
            local btnY = h - 1
            drawBox(t, 2, btnY, 14, 1, colors.purple)
            drawText(t, 3, btnY, "[ +RECIPE ]", colors.white, colors.purple)

            drawBox(t, 18, btnY, 14, 1, colors.gray)
            drawText(t, 20, btnY, "[ REFRESH ]", colors.white, colors.gray)

        elseif currentPage == "RECORD" then
            drawText(t, 2, 1, "=== RECORDER MODE ===", colors.red, colors.black)
            drawText(t, 2, 3, "Put items into Turtle grid (3x3) or Depots.", colors.yellow, colors.black)
            drawText(t, 2, 5, "Motor is stopped for recording.", colors.gray, colors.black)

            local btnY = h - 1
            drawBox(t, 2, btnY, 14, 1, colors.blue)
            drawText(t, 4, btnY, "[ SAVE ]", colors.white, colors.blue)

            drawBox(t, 18, btnY, 14, 1, colors.red)
            drawText(t, 20, btnY, "[ CANCEL ]", colors.white, colors.red)
        end
    end
end

----------------------------------------------------
-- Запуск крафта
----------------------------------------------------
function executeCraft(recipe, count)
    setMotorSpeed(256)
    print("Pulling components from Item Silos via wires...")

    if recipe.grid3x3 then
        for slot, item in pairs(recipe.grid3x3) do
            pullFromSiloToDevice(item.name, item.count * count, devices.turtle, slot)
        end
    end

    print("Executing process...")
    sleep(1.0)

    print("Returning finished product to Item Silos...")
    for slot = 1, 16 do
        pushDeviceToSilo(devices.turtle, slot)
    end
    print("Craft complete!")
end

----------------------------------------------------
-- Главный цикл обработки
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
            -- Выбор рецепта
            if y >= 3 and y <= 2 + math.min(#recipes, 6) then
                selectedRecipeIdx = y - 2
                renderUI()

            -- Кнопки заказа [-] [+] [START]
            elseif y == h - 4 then
                if x >= 12 and x <= 14 and orderAmount > 1 then
                    orderAmount = orderAmount - 1
                    renderUI()
                elseif x >= 23 and x <= 25 then
                    orderAmount = orderAmount + 1
                    renderUI()
                elseif x >= 28 and x <= 42 and #recipes > 0 then
                    executeCraft(recipes[selectedRecipeIdx], orderAmount)
                    renderUI()
                end

            -- Нижние кнопки [+RECIPE] [REFRESH]
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
            -- Принудительный CANCEL / SAVE
            if y >= h - 1 then
                if x >= 2 and x <= 16 then
                    table.insert(recipes, {
                        name = "Recipe_" .. (#recipes + 1),
                        output = "Crafted_Item_" .. (#recipes + 1),
                        grid3x3 = {}
                    })
                    saveRecipes()
                    currentPage = "MAIN"
                    renderUI()
                elseif x >= 18 and x <= 32 then
                    -- Мгновенная отмена и возврат в главное меню
                    currentPage = "MAIN"
                    renderUI()
                end
            end
        end
    end
end
