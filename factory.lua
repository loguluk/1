-- Master Factory Controller v13.0
-- Fixed Instant Transition on Scan + Stack (64) / +30 Buttons

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
local currentPage = "MAIN" -- "MAIN", "RECORD", "CONFIRM"
local selectedRecipeIdx = 1
local orderAmount = 1

local pendingRecipe = nil
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
-- Сетевой обмен Rednet
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

function setMotorSpeed(speed)
    if motorName and peripheral.isPresent(motorName) then
        local m = peripheral.wrap(motorName)
        if m and m.setSpeed then m.setSpeed(speed) end
    end
end

----------------------------------------------------
-- Запись и Ожидание результата крафта
----------------------------------------------------
function startRecipeScan()
    print("Scanning Turtle input grid...")
    local grid = requestTurtleScan()
    
    if not grid then
        print("Error: Turtle 21 not responding via Rednet!")
        return false
    end

    local ingredients = {}
    for slot, item in pairs(grid) do
        table.insert(ingredients, {
            slot = slot,
            name = item.name,
            count = item.count
        })
    end

    if #ingredients == 0 then
        print("Turtle grid is empty!")
        return false
    end

    print("Executing test craft on Turtle...")
    requestTurtleCraft()
    
    -- Ожидание 1 сек, чтобы крафт точно завершился
    sleep(1.0)

    -- Сканируем 1-й слот черепашки после крафта
    local afterGrid = requestTurtleScan()
    if afterGrid and afterGrid[1] then
        detectedOutputItem = afterGrid[1].name:gsub(".*:", "")
    else
        detectedOutputItem = "Crafted_Result"
    end

    pendingRecipe = {
        name = "Recipe #" .. (#recipes + 1),
        output = detectedOutputItem,
        ingredients = ingredients
    }

    currentPage = "CONFIRM"
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

            -- Удобный селектор количества [-1] [Qty] [+1] [+10] [+30] [STACK]
            drawBox(t, 2, h - 5, w - 4, 3, colors.gray)
            
            drawBox(t, 3, h - 4, 3, 1, colors.red)
            drawText(t, 4, h - 4, "-", colors.white, colors.red)

            drawBox(t, 7, h - 4, 7, 1, colors.black)
            drawText(t, 8, h - 4, string.format("%3d pcs", orderAmount), colors.yellow, colors.black)

            drawBox(t, 15, h - 4, 3, 1, colors.green)
            drawText(t, 16, h - 4, "+", colors.white, colors.green)

            drawBox(t, 19, h - 4, 5, 1, colors.orange)
            drawText(t, 20, h - 4, "+10", colors.white, colors.orange)

            drawBox(t, 25, h - 4, 5, 1, colors.purple)
            drawText(t, 26, h - 4, "+30", colors.white, colors.purple)

            drawBox(t, 31, h - 4, 7, 1, colors.blue)
            drawText(t, 32, h - 4, "[STK]", colors.white, colors.blue)

            drawBox(t, 39, h - 4, 9, 1, colors.lime)
            drawText(t, 40, h - 4, "[CRAFT]", colors.black, colors.lime)

            drawBox(t, 49, h - 4, 7, 1, colors.red)
            drawText(t, 50, h - 4, "[DEL]", colors.white, colors.red)

            -- Системная панель
            local btnY = h - 1
            drawBox(t, 2, btnY, 14, 1, colors.purple)
            drawText(t, 3, btnY, "[ +RECIPE ]", colors.white, colors.purple)

            drawBox(t, 18, btnY, 14, 1, colors.blue)
            drawText(t, 20, btnY, "[ REFRESH ]", colors.white, colors.blue)

        elseif currentPage == "RECORD" then
            drawText(t, 2, 1, "=== RECORDER MODE ===", colors.red, colors.black)
            drawText(t, 2, 3, "1. Place ingredients in Turtle 21 slots.", colors.yellow, colors.black)
            drawText(t, 2, 4, "2. Click [ SCAN NOW ] below.", colors.white, colors.black)

            local btnY = h - 1
            drawBox(t, 2, btnY, 14, 1, colors.green)
            drawText(t, 3, btnY, "[ SCAN NOW ]", colors.black, colors.green)

            drawBox(t, 18, btnY, 14, 1, colors.red)
            drawText(t, 20, btnY, "[ CANCEL ]", colors.white, colors.red)

        elseif currentPage == "CONFIRM" then
            drawText(t, 2, 1, "=== CONFIRM CRAFT RESULT ===", colors.yellow, colors.black)
            drawText(t, 2, 3, "Result in Turtle Slot 1:", colors.white, colors.black)
            drawText(t, 4, 4, "-> " .. detectedOutputItem, colors.lime, colors.black)
            drawText(t, 2, 6, "Is this the correct output item?", colors.yellow, colors.black)

            local btnY = h - 1
            drawBox(t, 2, btnY, 14, 1, colors.green)
            drawText(t, 4, btnY, "[ YES / SAVE ]", colors.black, colors.green)

            drawBox(t, 18, btnY, 14, 1, colors.red)
            drawText(t, 20, btnY, "[ NO / CANCEL ]", colors.white, colors.red)
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

            -- Селектор количества [-1] [Text] [+1] [+10] [+30] [STK] [CRAFT] [DEL]
            elseif y == h - 4 then
                if x >= 3 and x <= 5 and orderAmount > 1 then
                    orderAmount = orderAmount - 1
                    renderUI()
                elseif x >= 15 and x <= 17 then
                    orderAmount = orderAmount + 1
                    renderUI()
                elseif x >= 19 and x <= 23 then
                    orderAmount = orderAmount + 10
                    renderUI()
                elseif x >= 25 and x <= 29 then
                    orderAmount = orderAmount + 30
                    renderUI()
                elseif x >= 31 and x <= 37 then
                    orderAmount = 64
                    renderUI()
                elseif x >= 7 and x <= 13 then
                    orderAmount = 1
                    renderUI()
                elseif x >= 39 and x <= 47 and #recipes > 0 then
                    setMotorSpeed(256)
                    requestTurtleCraft()
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
                    setMotorSpeed(0)
                    renderUI()
                elseif x >= 18 and x <= 32 then
                    renderUI()
                end
            end

        elseif currentPage == "RECORD" then
            if y >= h - 1 then
                if x >= 2 and x <= 16 then
                    startRecipeScan()
                    renderUI()
                elseif x >= 18 and x <= 32 then
                    currentPage = "MAIN"
                    renderUI()
                end
            end

        elseif currentPage == "CONFIRM" then
            if y >= h - 1 then
                if x >= 2 and x <= 16 then
                    if pendingRecipe then
                        table.insert(recipes, pendingRecipe)
                        saveRecipes()
                    end
                    currentPage = "MAIN"
                    renderUI()
                elseif x >= 18 and x <= 32 then
                    pendingRecipe = nil
                    currentPage = "MAIN"
                    renderUI()
                end
            end
        end
    end
end
