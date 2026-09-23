-- Master Factory Controller (100% Monitor 4-Wide GUI + Electric Motor Control)
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
    turtle     = "turtle_21",
    motor      = "create:electric_motor_5"
}

local recipes = {}
local currentPage = "MAIN" -- "MAIN" или "RECORD"

local isRecording = false
local currentRecordingData = {
    inputs = {},
    outputs = {},
    logs = {}
}
local initialSnap = {}
local motorState = false -- false = Speed 0 (STOP), true = Speed 256 (RUN)

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
-- Управление Electric Motor (create:electric_motor_5)
----------------------------------------------------
function setMotorSpeed(speed)
    if peripheral.isPresent(devices.motor) then
        local motor = peripheral.wrap(devices.motor)
        if motor and motor.setSpeed then
            motor.setSpeed(speed)
            return true
        end
    end
    return false
end

----------------------------------------------------
-- Отрисовка UI для Монитора 4 блока
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

function snapshotInventories()
    local snap = {}
    for label, devName in pairs(devices) do
        if devName ~= devices.motor and peripheral.isPresent(devName) then
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
    monitor.write("============================== AUTO-FACTORY CONTROLLER (4-WIDE) ==============================")

    -- Устройства
    monitor.setCursorPos(2, 4)
    monitor.setTextColor(colors.cyan)
    monitor.write("CONNECTED DEVICES:")

    local statusY = 5
    local col = 4
    for label, name in pairs(devices) do
        monitor.setCursorPos(col, statusY)
        if peripheral.isPresent(name) then
            monitor.setTextColor(colors.green)
            monitor.write("[+] " .. label .. " (" .. name .. ")")
        else
            monitor.setTextColor(colors.red)
            monitor.write("[-] " .. label .. " (OFFLINE)")
        end
        statusY = statusY + 1
        if statusY > 9 then
            statusY = 5
            col = col + 38
        end
    end

    -- Список рецептов
    monitor.setCursorPos(2, 11)
    monitor.setTextColor(colors.orange)
    monitor.write("STORED RECIPES (" .. #recipes .. "):")

    for i, r in ipairs(recipes) do
        if i <= 5 then
            monitor.setCursorPos(4, 11 + i)
            monitor.setTextColor(colors.lightBlue)
            monitor.write(i .. ". " .. (r.name or "Recipe") .. " -> Output: " .. (r.output or "Unknown"))
        end
    end

    -- Кнопки главного меню
    drawButton(2, 18, 30, 4, colors.blue, colors.white, "[ RECORD RECIPE ]")
    drawButton(34, 18, 24, 4, colors.gray, colors.white, "[ REFRESH ]")
end

----------------------------------------------------
-- ЭКРАН 2: Запись и Мотор
----------------------------------------------------
function drawRecordPage()
    monitor.setBackgroundColor(colors.black)
    monitor.clear()

    monitor.setCursorPos(2, 2)
    monitor.setTextColor(colors.red)
    monitor.write("=========================== RECORDER MODE (REAL-TIME MONITORING) ===========================")

    -- Состояние мотора
    monitor.setCursorPos(2, 4)
    monitor.setTextColor(colors.white)
    monitor.write("ELECTRIC MOTOR 5 STATUS: ")
    if motorState then
        monitor.setTextColor(colors.green)
        monitor.write("RUNNING (256 RPM)")
    else
        monitor.setTextColor(colors.red)
        monitor.write("STOPPED (0 RPM)")
    end

    -- Содержимое блоков
    monitor.setCursorPos(2, 6)
    monitor.setTextColor(colors.cyan)
    monitor.write("CURRENT ITEMS ON MACHINES:")

    local currentSnap = snapshotInventories()
    local lineY = 7

    for label, devName in pairs(devices) do
        if devName ~= devices.motor and currentSnap[devName] then
            for slot, item in pairs(currentSnap[devName]) do
                if lineY <= 12 then
                    monitor.setCursorPos(4, lineY)
                    monitor.setTextColor(colors.yellow)
                    monitor.write("-> " .. label .. " (slot " .. slot .. "): ")
                    monitor.setTextColor(colors.lime)
                    monitor.write(item.count .. "x " .. item.name:gsub(".*:", ""))
                    lineY = lineY + 1
                end
            end
        end
    end

    if lineY == 7 then
        monitor.setCursorPos(4, 7)
        monitor.setTextColor(colors.gray)
        monitor.write("(No items placed on machines yet...)")
    end

    -- Кнопка мотора и записи
    if motorState then
        drawButton(2, 14, 32, 3, colors.red, colors.white, "[ STOP MOTOR (SET SPEED 0) ]")
    else
        drawButton(2, 14, 32, 3, colors.green, colors.black, "[ START MOTOR (SET SPEED 256) ]")
    end

    -- Лог
    monitor.setCursorPos(2, 18)
    monitor.setTextColor(colors.orange)
    monitor.write("LOG: ")
    if #currentRecordingData.logs > 0 then
        monitor.setTextColor(colors.lightGray)
        monitor.write(currentRecordingData.logs[#currentRecordingData.logs])
    end

    -- Кнопки сохранения/отмены
    drawButton(2, 20, 24, 3, colors.blue, colors.white, "[ SAVE RECIPE ]")
    drawButton(28, 20, 24, 3, colors.gray, colors.white, "[ CANCEL ]")
end

----------------------------------------------------
-- Логика Записи
----------------------------------------------------
function startRecording()
    currentPage = "RECORD"
    isRecording = true
    motorState = false
    setMotorSpeed(0) -- Останавливаем мотор при входе
    initialSnap = snapshotInventories()
    currentRecordingData = {
        inputs = {},
        outputs = {},
        logs = { "Recorder initialized. Motor set to 0 RPM." }
    }
    drawRecordPage()
end

function processRecordingStep()
    if not isRecording then return end
    local nowSnap = snapshotInventories()

    for devName, slots in pairs(nowSnap) do
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

function toggleMotor()
    motorState = not motorState
    if motorState then
        setMotorSpeed(256)
        table.insert(currentRecordingData.logs, "Motor turned ON (256 RPM)")
    else
        setMotorSpeed(0)
        table.insert(currentRecordingData.logs, "Motor turned OFF (0 RPM)")
    end
    drawRecordPage()
end

function saveCurrentRecipe()
    local recipeName = "Recipe_" .. (#recipes + 1)
    local newRecipe = {
        name = recipeName,
        output = currentRecordingData.output or "Process_Done",
        timestamp = os.time()
    }

    table.insert(recipes, newRecipe)
    saveRecipes()

    isRecording = false
    motorState = false
    setMotorSpeed(0)
    currentPage = "MAIN"
    drawMainPage()
end

----------------------------------------------------
-- Запуск и обработка нажатий на Мониторе
----------------------------------------------------
drawMainPage()

parallel.waitForAny(
    -- Обработка кликов на мониторе
    function()
        while true do
            local event, side, x, y = os.pullEvent("monitor_touch")

            if currentPage == "MAIN" then
                if y >= 18 and y <= 21 then
                    if x >= 2 and x <= 31 then
                        startRecording()
                    elseif x >= 34 and x <= 58 then
                        drawMainPage()
                    end
                end
            elseif currentPage == "RECORD" then
                -- Кнопка управления мотором (y: 14-16)
                if y >= 14 and y <= 16 and x >= 2 and x <= 33 then
                    toggleMotor()
                -- Кнопка Сохранить (y: 20-22)
                elseif y >= 20 and y <= 22 and x >= 2 and x <= 25 then
                    saveCurrentRecipe()
                -- Кнопка Отмена (y: 20-22)
                elseif y >= 20 and y <= 22 and x >= 28 and x <= 51 then
                    isRecording = false
                    setMotorSpeed(0)
                    currentPage = "MAIN"
                    drawMainPage()
                end
            end
        end
    end,

    -- Таймер авто-обновления монитора (раз в 1 сек)
    function()
        while true do
            sleep(1)
            if isRecording and currentPage == "RECORD" then
                processRecordingStep()
            end
        end
    end
)
