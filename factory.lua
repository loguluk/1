-- Master Factory & Auto-Craft Controller
-- Monitor: 5x4 Advanced Monitor

-- 1. Подключение монитора
local monitor = peripheral.find("monitor")
if monitor then
    monitor.setTextScale(0.5)
    monitor.clear()
end

-- 2. Обновленная карта устройств
local devices = {
    depotPress  = "create:depot_14",
    depotArm    = "create:depot_16",
    deployer    = "create:deployer_9",
    basinPress  = "create:basin_10",
    basinMixer  = "create:basin_11",
    turtle      = "turtle_21",      -- Черепашка в сети
    turtleId    = 104               -- Реальный ID черепашки
}

local recipes = {}

-- Отрисовка статуса на мониторе 5x4
function updateMonitor()
    if not monitor then return end
    monitor.setBackgroundColor(colors.black)
    monitor.clear()

    -- Заголовок
    monitor.setCursorPos(2, 2)
    monitor.setTextColor(colors.yellow)
    monitor.write("=== CREATE AUTO-FACTORY (STATION 104) ===")

    -- Подключенные механизмы
    monitor.setCursorPos(2, 4)
    monitor.setTextColor(colors.cyan)
    monitor.write("ПОДКЛЮЧЁННЫЕ УЗЛЫ:")

    local nodes = {
        {"Депо Пресса", devices.depotPress},
        {"Депо Руки", devices.depotArm},
        {"Мех. Рука", devices.deployer},
        {"Чаша Пресса", devices.basinPress},
        {"Чаша Миксера", devices.basinMixer},
        {"Черепашка (Депо)", devices.turtle .. " [ID: " .. devices.turtleId .. "]"}
    }

    for i, node in ipairs(nodes) do
        monitor.setCursorPos(4, 4 + i)
        monitor.setTextColor(colors.white)
        monitor.write("- " .. node[1] .. " -> ")
        
        -- Проверка активности периферии в сети
        if peripheral.isPresent(node[2]:match("^[^%s]+") or node[2]) then
            monitor.setTextColor(colors.lightGray)
            monitor.write(node[2])
        else
            monitor.setTextColor(colors.red)
            monitor.write(node[2] .. " (НЕ НАЙДЕНО)")
        end
    end

    -- Сохраненные рецепты
    monitor.setCursorPos(2, 12)
    monitor.setTextColor(colors.green)
    monitor.write("РЕЦЕПТЫ В БАЗЕ (" .. #recipes .. "):")

    for i, r in ipairs(recipes) do
        if i <= 10 then
            monitor.setCursorPos(4, 12 + i)
            monitor.setTextColor(colors.lightBlue)
            monitor.write(i .. ". " .. r.name .. " [" .. r.targetDevice .. "]")
        end
    end
end

-- Функция сканирования рецепта
function recordRecipe(recipeName)
    local newRecipe = {
        name = recipeName,
        ingredients = {},
        targetDevice = "UNKNOWN"
    }

    local stationPeripherals = {
        ["Депо Пресса"]  = devices.depotPress,
        ["Депо Руки"]    = devices.depotArm,
        ["Чаша Пресса"]  = devices.basinPress,
        ["Чаша Миксера"] = devices.basinMixer,
        ["Рука"]         = devices.deployer,
        ["Черепашка"]    = devices.turtle
    }

    for devLabel, pName in pairs(stationPeripherals) do
        local pObj = peripheral.wrap(pName)
        if pObj and pObj.list then
            local items = pObj.list()
            for slot, item in pairs(items) do
                table.insert(newRecipe.ingredients, {
                    device = pName,
                    deviceLabel = devLabel,
                    slot = slot,
                    name = item.name,
                    count = item.count
                })
                newRecipe.targetDevice = devLabel
            end
        end
    end

    table.insert(recipes, newRecipe)
    updateMonitor()
    print("Рецепт '" .. recipeName .. "' успешно записан! Ингредиентов: " .. #newRecipe.ingredients)
end

-- Главный интерфейс
while true do
    term.clear()
    term.setCursorPos(1, 1)
    print("=================================")
    print("  ТЕРМИНАЛ ФАБРИКИ (ЧЕРЕПАШКА 104) ")
    print("=================================")
    print("1. Сканировать и записать рецепт")
    print("2. Проверить связь с Черепашкой (104)")
    print("3. Обновить большой монитор")
    print("---------------------------------")
    write("Выберите действие: ")

    local choice = read()

    if choice == "1" then
        write("\nВведите название нового рецепта: ")
        local name = read()
        recordRecipe(name)
        sleep(2)

    elseif choice == "2" then
        print("\nПроверка связи с turtle_21...")
        if peripheral.isPresent(devices.turtle) then
            print("Успех: Черепашка 104 (" .. devices.turtle .. ") подключена к сети!")
        else
            print("Ошибка: Черепашка 104 не видна в сети. Проверь проводной модем!")
        end
        sleep(2)

    elseif choice == "3" then
        updateMonitor()
    end
end
