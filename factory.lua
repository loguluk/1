-- Master Factory Controller (100% Monitor GUI + Real-time Recording)
-- Connected Turtle: turtle_21 (ID: 104)

local RECIPE_FILE = "recipes.json"

local monitor = peripheral.find("monitor")
if not monitor then
    error("Error: Monitor not found!")
end

monitor.setTextScale(0.5)
monitor.clear()

local devices = {
    depotPress = "create:depot_14",
    depotArm   = "create:depot_16",
    deployer   = "create:deployer_9",
    basinPress = "create:basin_10",
    basinMixer = "create:basin_11",
    turtle     = "turtle_21"
}

local recipes = {}
local currentPage = "MAIN" -- Страницы: "MAIN" или "RECORD"

-- Переменные для онлайн-записи
local isRecording = false
local currentRecordingData = {
    inputs = {},
    outputs = {},
    logs = {}
}
local initialSnap = {}

----------------------------------------------------
-- Загрузка и Сохранение рецептов
----------------------------------------------------
function loadRecipes()
    if fs.exists(RECIPE_FILE) then
        local f = fs.open(RECIPE_FILE, "r")
        local data = f.readAll()
        f.close()
        recipes = textutils.unserializeJSON(data) or {}
    end
end

function saveRecipes()
    local f = fs.open(RECIPE_FILE, "w")
    f.write(textutils.serializeJSON(recipes))
    f.close()
end

loadRecipes()

----------------------------------------------------
-- Отрисовка элементов UI
----------------------------------------------------
function drawButton(x, y, w, h, bg, textColor, text)
    monitor.setBackgroundColor(bg)
    monitor.setTextColor(textColor)
    for i = 0, h - 1 do
        monitor.setCursorPos(x, y + i)
        monitor.write(string.rep(" ", w))
    end
    local textX = x + math.floor((w - #text) / 2)
    monitor.setCursorPos(textX, y + math.floor(h / 2))
    monitor.write(text)
    monitor.setBackgroundColor(colors.black)
end

-- Снимок всех инвентарей
function snapshotInventories()
    local snap = {}
    for label, devName in pairs(devices) do
        if peripheral.isPresent(devName) then
            local p = peripheral.wrap(devName)
            if p and p.list then
                snap[devName] = {}
                local items = p.list()
                for slot, item in pairs(items) do
                    snap[devName][slot] = { name = item.name, count = item.count }
                end
            end
        end
    end
    return snap
end

----------------------------------------------------
-- ЭКРАН 1: Главный Дашборд
----------------------------------------------------
function drawMainPage()
    monitor.setBackgroundColor(colors.black)
    monitor.clear()

    -- Шапка
    monitor.setCursorPos(2, 2)
    monitor.setTextColor(colors.yellow)
    monitor.write("=== AUTO-FACTORY CONTROLLER (TURTLE 104) ===")

    -- Статус устройств
    monitor.setCursorPos(2, 4)
    monitor.setTextColor(colors.cyan)
    monitor.write("CONNECTED DEVICES:")

    local statusY = 5
    for label, name in pairs(devices) do
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

    -- Список сохранённых рецептов
    monitor.setCursorPos(2, 12)
    monitor.setTextColor(colors.orange)
    monitor.write("STORED RECIPES (" .. #recipes .. "):")

    for i, r in ipairs(recipes) do
        if i <= 5 then
            monitor.setCursorPos(4, 12 + i)
            monitor.setTextColor(colors.lightBlue)
            monitor.write(i .. ". " .. (r.name or "Recipe") .. " -> " .. (r.output or "Unknown"))
        end
    end

    -- Кнопка записи
    drawButton(2, 19, 24, 3, colors.blue, colors.white, "[ RECORD RECIPE ]")
    drawButton(28, 19, 20, 3, colors.gray, colors.white, "[ REFRESH ]")
end

----------------------------------------------------
-- ЭКРАН 2: Страница записи в реальном времени
----------------------------------------------------
function drawRecordPage()
    monitor.setBackgroundColor(colors.black)
    monitor.clear()

    -- Заголовок режима записи
    monitor.setCursorPos(2, 2)
    monitor.setTextColor(colors.red)
    monitor.write("=== RECORDER MODE (LIVE TRACKING 1s) ===")

    monitor.setCursorPos(2, 4)
    monitor.setTextColor(colors.white)
    monitor.write("Current Items on Devices:")

    -- Живой список всех находящихся предметов
    local currentSnap = snapshotInventories()
    local lineY = 5

    for label, devName in pairs(devices) do
        if currentSnap[devName] then
            for slot, item in pairs(currentSnap[devName]) do
                if lineY <= 12 then
                    monitor.setCursorPos(4, lineY)
                    monitor.setTextColor(colors.yellow)
                    monitor.write("-> " .. label .. ": ")
                    monitor.setTextColor(colors.lime)
                    monitor.write(item.count .. "x " .. item.name:gsub(".*:", ""))
                    lineY = lineY + 1
                end
            end
        end
    end

    if lineY == 5 then
        monitor.setCursorPos(4, 5)
        monitor.setTextColor(colors.gray)
        monitor.write("(No items detected on depots/basins...)")
    end

    -- Лог событий
    monitor.setCursorPos(2, 14)
    monitor.setTextColor(colors.cyan)
    monitor.write("EVENT LOG:")

    local logStart = math.max(1, #currentRecordingData.logs - 3)
    local displayIdx = 0
    for i = logStart, #currentRecordingData.logs do
        monitor.setCursorPos(4, 15 + displayIdx)
        monitor.setTextColor(colors.lightGray)
        monitor.write(currentRecordingData.logs[i])
        displayIdx = displayIdx + 1
    end

    -- Кнопки управления записью
    drawButton(2, 19, 22, 3, colors.green, colors.black, "[ SAVE RECIPE ]")
    drawButton(26, 19, 22, 3, colors.red, colors.white, "[ CANCEL ]")
end

----------------------------------------------------
-- Логика Записи и Отслеживания
----------------------------------------------------
function startRecording()
    currentPage = "RECORD"
    isRecording = true
    initialSnap = snapshotInventories()
    currentRecordingData = {
        inputs = {},
        outputs = {},
        logs = { "Started recording..." }
    }
    drawRecordPage()
end

function processRecordingStep()
    if not isRecording then return end
    local nowSnap = snapshotInventories()

    for devName, slots in pairs(nowSnap) do
        -- Ищем короткое имя устройства
        local shortLabel = devName
        for l, n in pairs(devices) do
            if n == devName then shortLabel = l break end
        end

        for slot, item in pairs(slots) do
            local prevCount = (initialSnap[devName] and initialSnap[devName][slot]) and initialSnap[devName][slot].count or 0
            local diff = item.count - prevCount

            if diff > 0 then
                local logMsg = "+" .. diff .. " " .. item.name:gsub(".*:", "") .. " at " .. shortLabel
                if #currentRecordingData.logs == 0 or currentRecordingData.logs[#currentRecordingData.logs] ~= logMsg then
                    table.insert(currentRecordingData.logs, logMsg)
                    currentRecordingData.output = item.name
                end
            end
        end
    end
    drawRecordPage()
end

function saveCurrentRecipe()
    local finalSnap = snapshotInventories()
    local recipeName = "Recipe_" .. (#recipes + 1)
    
    local newRecipe = {
        name = recipeName,
        output = currentRecordingData.output or "Process_Done",
        timestamp = os.time()
    }

    table.insert(recipes, newRecipe)
    saveRecipes()

    isRecording = false
    currentPage = "MAIN"
    drawMainPage()
end

----------------------------------------------------
-- Главный цикл обработки событий
----------------------------------------------------
drawMainPage()

parallel.waitForAny(
    -- 1. Клики по монитору
    function()
        while true do
            local event, side, x, y = os.pullEvent("monitor_touch")
            
            if currentPage == "MAIN" then
                if y >= 19 and y <= 21 then
                    if x >= 2 and x <= 26 then
                        startRecording()
                    elseif x >= 28 and x <= 48 then
                        drawMainPage()
                    end
                end
            elseif currentPage == "RECORD" then
                if y >= 19 and y <= 21 then
                    if x >= 2 and x <= 24 then
                        saveCurrentRecipe()
                    elseif x >= 26 and x <= 48 then
                        isRecording = false
                        currentPage = "MAIN"
                        drawMainPage()
                    end
                end
            end
        end
    end,

    -- 2. Таймер обновления записи (каждую 1 секунду)
    function()
        while true do
            sleep(1)
            if isRecording and currentPage == "RECORD" then
                processRecordingStep()
            end
        end
    end
)
