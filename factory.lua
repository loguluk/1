-- Master Auto-Factory & Crafting Station
-- Target Turtle: turtle_21 (ID: 104)

local monitor = peripheral.find("monitor")
if not monitor then
    error("Ошибка: Монитор 5x4 не найден!")
end

monitor.setTextScale(0.5)

-- Список устройств
local dev = {
    depotPress = "create:depot_14",
    depotArm   = "create:depot_16",
    deployer   = "create:deployer_9",
    basinPress = "create:basin_10",
    basinMixer = "create:basin_11",
    turtle     = "turtle_21"
}

local recipes = {}
local RECIPE_FILE = "recipes.json"

-- Загрузка рецептов из файла
function loadRecipes()
    if fs.exists(RECIPE_FILE) then
        local file = fs.open(RECIPE_FILE, "r")
        recipes = textutils.unserializeJSON(file.readAll()) or {}
        file.close()
    end
end

-- Сохранение рецептов в файл
function saveRecipes()
    local file = fs.open(RECIPE_FILE, "w")
    file.write(textutils.serializeJSON(recipes))
    file.close()
end

loadRecipes()

-- Отрисовка интерфейса на мониторе 5x4
function drawMonitor()
    monitor.setBackgroundColor(colors.black)
    monitor.clear()

    -- Шапка
    monitor.setCursorPos(2, 2)
    monitor.setTextColor(colors.yellow)
    monitor.write("=== AUTO-FACTORY 3x3 & CREATE ===")

    -- Статус устройств
    monitor.setCursorPos(2, 4)
    monitor.setTextColor(colors.cyan)
    monitor.write("УСТРОЙСТВА В СЕТИ:")

    local statusY = 5
    for label, name in pairs(dev) do
        monitor.setCursorPos(4, statusY)
        if peripheral.isPresent(name) then
            monitor.setTextColor(colors.green)
            monitor.write("[+] " .. label .. " (" .. name .. ")")
        else
            monitor.setTextColor(colors.red)
            monitor.write("[-] " .. label .. " (OFFLINE)")
        end
        statusY = statusY + 1
    end

    -- Список рецептов
    monitor.setCursorPos(2, 12)
    monitor.setTextColor(colors.orange)
    monitor.write("СОХРАНЁННЫЕ РЕЦЕПТЫ (" .. #recipes .. "):")

    for i, r in ipairs(recipes) do
        if i <= 6 then
            monitor.setCursorPos(4, 12 + i)
            monitor.setTextColor(colors.white)
            monitor.write(i .. ". " .. r.name .. " [" .. r.type .. "]")
        end
    end

    -- Интерактивные кнопки
    drawButton(2, 20, 22, 3, colors.blue, " [1] ЗАПИСАТЬ РЕЦЕПТ ")
    drawButton(26, 20, 22, 3, colors.lime, " [2] СРАЗУ СКАНИРОВАТЬ ")
end

function drawButton(x, y, w, h, bg, text)
    monitor.setBackgroundColor(bg)
    monitor.setTextColor(colors.white)
    for i = 0, h - 1 do
        monitor.setCursorPos(x, y + i)
        monitor.write(string.rep(" ", w))
    end
    monitor.setCursorPos(x + 1, y + math.floor(h / 2))
    monitor.write(text)
    monitor.setBackgroundColor(colors.black)
end

-- Считывание состояния всех блоков (поддержка нескольких предметов в чашах)
function scanAllInventories()
    local snapshot = {}
    local targets = {
        dev.depotPress, dev.depotArm, dev.basinPress, 
        dev.basinMixer, dev.deployer, dev.turtle
    }

    for _, pName in ipairs(targets) do
        local obj = peripheral.wrap(pName)
        if obj and obj.list then
            snapshot[pName] = {}
            local items = obj.list()
            for slot, item in pairs(items) do
                table.insert(snapshot[pName], {
                    slot = slot,
                    name = item.name,
                    count = item.count
                })
            end
        end
    end
    return snapshot
end

-- Запись рецепта с шаблоном 3x3 и мульти-компонентами
function recordNewRecipe(recipeName)
    term.clear()
    term.setCursorPos(1, 1)
    print("=== ЗАПИСЬ НОВОГО РЕЦЕПТА: " .. recipeName .. " ===")
    print("1. Разложите ингредиенты по блокам / в сетку черепашки 3x3.")
    print("2. Нажмите ENTER, когда всё будет готово к сканированию...")
    read()

    local initialInputs = scanAllInventories()
    
    local newRecipe = {
        name = recipeName,
        type = "3x3_TURTLE",
        grid3x3 = {},
        basins = {},
        depots = {}
    }

    -- 1. Сканируем Turtle 21 на наличие шаблона 3x3
    local turtleObj = peripheral.wrap(dev.turtle)
    if turtleObj and turtleObj.list then
        local tItems = turtleObj.list()
        for slot, item in pairs(tItems) do
            if slot <= 9 then -- Первые 9 слотов образуют сетку крафта 3x3
                newRecipe.grid3x3[slot] = { name = item.name, count = item.count }
            end
        end
    end

    -- 2. Сканируем Чаши (Basin 10 / Basin 11) на мульти-предметы
    for _, basinName in ipairs({dev.basinPress, dev.basinMixer}) do
        if initialInputs[basinName] then
            newRecipe.basins[basinName] = initialInputs[basinName]
        end
    end

    table.insert(recipes, newRecipe)
    saveRecipes()
    drawMonitor()

    print("Успех! Рецепт '" .. recipeName .. "' сохранён в recipes.json!")
    sleep(2)
end

-- Обработка нажатий на мониторе
function handleMonitorTouch()
    while true do
        local event, side, x, y = os.pullEvent("monitor_touch")
        
        -- Кнопка "ЗАПИСАТЬ РЕЦЕПТ"
        if y >= 20 and y <= 22 and x >= 2 and x <= 24 then
            term.clear()
            term.setCursorPos(1, 1)
            write("Введите имя нового рецепта: ")
            local name = read()
            if name ~= "" then
                recordNewRecipe(name)
            end
        end
    end
end

-- Главный поток
drawMonitor()
parallel.waitForAny(
    handleMonitorTouch,
    function()
        while true do
            term.clear()
            term.setCursorPos(1, 1)
            print("=================================")
            print("   ТЕРМИНАЛ УПРАВЛЕНИЯ ФАБРИКОЙ   ")
            print("=================================")
            print("1. Записать новый рецепт")
            print("2. Перерисовать монитор")
            print("3. Проверить файл recipes.json")
            print("---------------------------------")
            write("Выберите действие: ")
            
            local c = read()
            if c == "1" then
                write("Имя рецепта: ")
                local name = read()
                recordNewRecipe(name)
            elseif c == "2" then
                drawMonitor()
            elseif c == "3" then
                print("Файл сохранён. Записей: " .. #recipes)
                sleep(2)
            end
        end
    end
)
