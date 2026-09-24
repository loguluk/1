-- Factory Controller with Create Connected Item Silos Integration
-- Handles item pulling/pushing from Silos 94-101 and UI navigation

local RECIPE_FILE = "recipes.json"
local monitor = peripheral.find("monitor")

if monitor then
    monitor.setTextScale(0.5)
    monitor.clear()
end
term.clear()

-- Список силосных башен хранилища
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
local currentPage = "MAIN" -- "MAIN", "ORDER", "RECORD"
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
-- Работа с Item Silo (Хранилище)
----------------------------------------------------
-- Забрать нужное количество предмета из Silo в Turtle
function pullFromSilos(itemName, count, targetSlot)
    local remaining = count
    for _, siloName in ipairs(silos) do
        if peripheral.isPresent(siloName) then
            local silo = peripheral.wrap(siloName)
            local items = silo.list()
            for slot, item in pairs(items) do
                if item.name == itemName then
                    local moved = silo.pushItems(devices.turtle, slot, remaining, targetSlot)
                    remaining = remaining - moved
                    if remaining <= 0 then return true end
                end
            end
        end
    end
    return remaining < count
end

-- Отправить готовый предмет из Turtle в первое свободное Silo
function pushToSilos(turtleSlot)
    local turtleObj = peripheral.wrap(devices.turtle) or turtle
    for _, siloName in ipairs(silos) do
        if peripheral.isPresent(siloName) then
            local moved = turtleObj.pushItems(siloName, turtleSlot)
            if moved > 0 then return true end
        end
    end
    return false
end

----------------------------------------------------
-- Управление Мотором
----------------------------------------------------
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
            drawText(t, 2, 1, "=== FACTORY AUTO-CRAFT (ITEM SILO CONNECTED) ===", colors.yellow, colors.black)
            drawText(t, 2, 2, "Select recipe to request:", colors.gray, colors.black)

            if #recipes == 0 then
                drawText(t, 4, 4, "No recipes found. Press [+RECIPE] to add.", colors.red, colors.black)
            else
                for i, r in ipairs(recipes) do
                    if i <= 8 then
                        local isSel = (i == selectedRecipeIdx)
                        local prefix = isSel and "> " or "  "
                        local bgCol = isSel and colors.gray or colors.black
                        local fgCol = isSel and colors.white or colors.cyan
                        
                        drawBox(t, 2, 3 + i, w - 4, 1, bgCol)
                        drawText(t, 2, 3 + i, prefix .. i .. ". " .. (r.output or "Item") .. " [Auto-Silo]", fgCol, bgCol)
                    end
                end
            end

            local btnY = h - 1
            drawBox(t, 2, btnY, 14, 1, colors.blue)
            drawText(t, 3, btnY, "[ CRAFT ]", colors.white, colors.blue)

            drawBox(t, 18, btnY, 14, 1, colors.purple)
            drawText(t, 19, btnY, "[ +RECIPE ]", colors.white, colors.purple)

        elseif currentPage == "ORDER" then
            local r = recipes[selectedRecipeIdx]
            drawText(t, 2, 1, "=== ORDER ITEM ===", colors.yellow, colors.black)
            drawText(t, 2, 3, "Output: " .. (r.output or "Unknown"), colors.cyan, colors.black)
            drawText(t, 2, 5, "Select amount:", colors.white, colors.black)

            drawBox(t, 4, 7, 5, 1, colors.red)
            drawText(t, 6, 7, "-", colors.white, colors.red)

            drawText(t, 11, 7, tostring(orderAmount) .. " pcs", colors.yellow, colors.black)

            drawBox(t, 20, 7, 5, 1, colors.green)
            drawText(t, 22, 7, "+", colors.white, colors.green)

            local btnY = h - 1
            drawBox(t, 2, btnY, 14, 1, colors.lime)
            drawText(t, 4, btnY, "[ START ]", colors.black, colors.lime)

            drawBox(t, 18, btnY, 14, 1, colors.gray)
            drawText(t, 20, btnY, "[ CANCEL ]", colors.white, colors.gray)

        elseif currentPage == "RECORD" then
            drawText(t, 2, 1, "=== RECORDER MODE ===", colors.red, colors.black)
            drawText(t, 2, 3, "Setup items in Crafting Turtle...", colors.gray, colors.black)

            local btnY = h - 1
            drawBox(t, 2, btnY, 14, 1, colors.blue)
            drawText(t, 4, btnY, "[ SAVE ]", colors.white, colors.blue)

            drawBox(t, 18, btnY, 14, 1, colors.gray)
            drawText(t, 20, btnY, "[ CANCEL ]", colors.white, colors.gray)
        end
    end
end

----------------------------------------------------
-- Выполнение Автокрафта
----------------------------------------------------
function executeCraft(recipe, count)
    setMotorSpeed(256)
    print("Pulling ingredients from Item Silos...")

    if recipe.grid3x3 then
        for slot, item in pairs(recipe.grid3x3) do
            pullFromSilos(item.name, item.count * count, slot)
        end
    end

    print("Crafting process running...")
    sleep(1.0)

    -- Отправка результата обратно в Silo
    print("Storing finished items back into Item Silos...")
    for slot = 1, 16 do
        pushToSilos(slot)
    end
    print("Done!")
end

----------------------------------------------------
-- Обработка Кликов
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
            if y >= 4 and y <= 3 + #recipes then
                selectedRecipeIdx = y - 3
                renderUI()
            elseif y >= h - 1 then
                if x >= 2 and x <= 16 and #recipes > 0 then
                    currentPage = "ORDER"
                    orderAmount = 1
                    renderUI()
                elseif x >= 18 and x <= 32 then
                    currentPage = "RECORD"
                    setMotorSpeed(0)
                    renderUI()
                end
            end

        elseif currentPage == "ORDER" then
            if y == 7 then
                if x >= 4 and x <= 9 and orderAmount > 1 then
                    orderAmount = orderAmount - 1
                    renderUI()
                elseif x >= 20 and x <= 25 then
                    orderAmount = orderAmount + 1
                    renderUI()
                end
            elseif y >= h - 1 then
                if x >= 2 and x <= 16 then
                    -- Старт
                    executeCraft(recipes[selectedRecipeIdx], orderAmount)
                    currentPage = "MAIN"
                    renderUI()
                elseif x >= 18 and x <= 32 then
                    -- Отмена (Гарантированный возврат)
                    currentPage = "MAIN"
                    renderUI()
                end
            end

        elseif currentPage == "RECORD" then
            if y >= h - 1 then
                if x >= 2 and x <= 16 then
                    -- Сохранить
                    table.insert(recipes, {
                        name = "Recipe_" .. (#recipes + 1),
                        output = "Crafted_Item_" .. (#recipes + 1),
                        grid3x3 = {}
                    })
                    saveRecipes()
                    currentPage = "MAIN"
                    renderUI()
                elseif x >= 18 and x <= 32 then
                    -- Отмена (Гарантированный возврат)
                    currentPage = "MAIN"
                    renderUI()
                end
            end
        end
    end
end
