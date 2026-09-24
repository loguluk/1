-- Factory Controller v8.0 (Silos + Turtle + Manual Scan + Delete + Info)

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

-- Слоты сетки 3x3 у Turtle: 1,2,3 / 5,6,7 / 9,10,11
local craftGridSlots = {1, 2, 3, 5, 6, 7, 9, 10, 11}

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
-- Сохранение / Загрузка
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
-- Работа с мотором и силосами
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
-- Ручное сканирование рецепта (Кнопка SCAN NOW)
----------------------------------------------------
function scanCurrentRecipe()
    local ingredients = {}
    local mainOutput = "Unknown Item"
    local craftType = "TURTLE_CRAFT"

    -- Проверяем слоты Turtle 3x3
    if peripheral.isPresent(devices.turtle) then
        local t = peripheral.wrap(devices.turtle)
        local items = t.list()
        
        for _, slot in ipairs(craftGridSlots) do
            if items[slot] then
                table.insert(ingredients, {
                    slot = slot,
                    name = items[slot].name,
                    count = items[slot].count
                })
                mainOutput = items[slot].name .. "_crafted"
            end
        end
    end

    if #ingredients > 0 then
        table.insert(recipes, {
            name = "Recipe #" .. (#recipes + 1),
            output = mainOutput,
            type = craftType,
            ingredients = ingredients
        })
        saveRecipes()
        return true
    end
    return false
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

            -- Список рецептов
            if #recipes == 0 then
                drawText(t, 2, 3, "No recipes found. Click [+RECIPE] to add.", colors.red, colors.black)
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

                -- Инфо об ингредиентах выбранного рецепта
                local selR = recipes[selectedRecipeIdx]
                if selR then
                    local ingText = "Ingr: "
                    if selR.ingredients then
                        for _, ing in ipairs(selR.ingredients) do
                            ingText = ingText .. ing.count .. "x " .. ing.name:gsub(".*:", "") .. " "
                        end
                    end
                    drawText(t, 2, 8, ingText:sub(1, w - 4), colors.lightGray, colors.black)
                end
            end

            -- Панель количества и кнопки START / DELETE
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

            -- Нижняя системная панель
            local btnY = h - 1
            drawBox(t, 2, btnY, 14, 1, colors.purple)
            drawText(t, 3, btnY, "[ +RECIPE ]", colors.white, colors.purple)

            drawBox(t, 18, btnY, 14, 1, colors.blue)
            drawText(t, 20, btnY, "[ REFRESH ]", colors.white, colors.blue)

        elseif currentPage == "RECORD" then
            drawText(t, 2, 1, "=== RECORDER MODE ===", colors.red, colors.black)
            drawText(t, 2, 3, "1. Put ingredients into Turtle slots (1,2,3, 5,6,7, 9,10,11).", colors.yellow, colors.black)
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
-- Выполнение крафта черепашкой
----------------------------------------------------
function executeCraft(recipe, count)
    setMotorSpeed(256)
    print("Pulling ingredients from Item Silos...")

    if recipe.ingredients then
        for _, ing in ipairs(recipe.ingredients) do
            pullFromSiloToDevice(ing.name, ing.count * count, devices.turtle, ing.slot)
        end
    end

    print("Crafting via Turtle...")
    sleep(0.5)

    -- Если это черепашка, заставляем её вызвать turtle.craft() по сети
    if peripheral.isPresent(devices.turtle) then
        local t = peripheral.wrap(devices.turtle)
        if t and t.craft then
            t.craft()
        end
    end

    print("Storing finished items back into Item Silos...")
    for slot = 1, 16 do
        pushDeviceToSilo(devices.turtle, slot)
    end
    print("Craft finished!")
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
            -- Выбор рецепта в списке
            if y >= 3 and y <= 2 + math.min(#recipes, 5) then
                selectedRecipeIdx = y - 2
                renderUI()

            -- Управление заказом [-] [+] [START] [DELETE]
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
                    -- Удаление рецепта
                    table.remove(recipes, selectedRecipeIdx)
                    if selectedRecipeIdx > #recipes then selectedRecipeIdx = math.max(1, #recipes) end
                    saveRecipes()
                    renderUI()
                end

            -- Нижняя панель [+RECIPE] [REFRESH]
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
                    -- Кнопка SCAN NOW
                    if scanCurrentRecipe() then
                        currentPage = "MAIN"
                    end
                    renderUI()
                elseif x >= 18 and x <= 32 then
                    -- Мгновенная отмена
                    currentPage = "MAIN"
                    renderUI()
                end
            end
        end
    end
end
