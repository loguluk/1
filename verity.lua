local API_KEY = "YOUR_DEEPSEEK_API_KEY"
local API_URL = "https://api.deepseek.com/chat/completions"

if API_KEY == "YOUR_DEEPSEEK_API_KEY" then
    error("Укажите ваш API_KEY на первой строчке кода!")
end

-- Включаем работу с экраном компьютера
local display = term.current()
display.clear()

local w, h = display.getSize()

-- Системная инструкция для Верити
local history = {
    { 
        role = "system", 
        content = "Тебя зовут Верити. Ты живешь внутри компьютера в Minecraft ComputerCraft. Твоё самое первое сообщение ВСЕГДА должно начинаться со слов 'Привет, я Верити'. Ты немного глуповат, соображаешь медленно, отвечаешь просто и наивно. Делай в тексте небольшие, но понятные орфографические ошибки или опечатки (например, 'превет', 'шо', 'тута', 'щас', 'зачемь', 'компютер'), но так, чтобы смысл ответа оставался понятен. Не пиши слишком умные и длинные фразы." 
    }
}

-- Функция создания случайных графических помех (глюков) на мониторе
local function triggerScreenGlitch()
    if math.random(1, 2) == 1 then
        -- Выбираем случайную точку на мониторе
        local rx = math.random(1, math.max(1, w - 4))
        local ry = math.random(2, math.max(2, h - 1))
        
        -- Сохраняем позицию курсора
        local cx, cy = display.getCursorPos()
        
        display.setCursorPos(rx, ry)
        display.setBackgroundColor(colors.red)
        display.setTextColor(colors.yellow)
        
        local glitchTexts = { "ERR", "0x0", "???", "#!@", "GLITCH" }
        display.write(glitchTexts[math.random(1, #glitchTexts)])
        
        os.sleep(0.06)
        
        -- Восстанавливаем цвет и курсор
        display.setBackgroundColor(colors.black)
        display.setTextColor(colors.white)
        display.setCursorPos(cx, cy)
    end
end

-- Функция отрисовки графической шапки интерфейса
local function drawOSHeader()
    local cx, cy = display.getCursorPos()
    display.setCursorPos(1, 1)
    display.setBackgroundColor(colors.gray)
    display.setTextColor(colors.white)
    display.clearLine()
    display.write(" [VERITY OS] Mon: " .. w .. "x" .. h .. " | Status: OK ")
    display.setBackgroundColor(colors.black)
    display.setCursorPos(cx, cy)
end

-- Старт интерфейса
display.setBackgroundColor(colors.black)
display.clear()
drawOSHeader()

display.setCursorPos(1, 3)
display.setTextColor(colors.lightGray)
print("Монитор подключен. Верити готов...")
print("-----------------------------------")

while true do
    triggerScreenGlitch()

    -- Ввод с клавиатуры компьютера
    display.setTextColor(colors.yellow)
    write("\nВы > ")
    display.setTextColor(colors.white)
    
    local input = read()

    if input:lower() == "exit" or input:lower() == "quit" then
        display.setTextColor(colors.lightGray)
        print("Верити выключился...")
        break
    end

    if #input > 0 then
        table.insert(history, { role = "user", content = input })

        display.setTextColor(colors.gray)
        print("Верити думати...")
        
        triggerScreenGlitch()

        -- Запрос к DeepSeek API
        local requestData = textutils.serializeJSON({
            model = "deepseek-chat",
            messages = history,
            stream = false
        })

        local headers = {
            ["Content-Type"] = "application/json",
            ["Authorization"] = "Bearer " .. API_KEY
        }

        local response = http.post(API_URL, requestData, headers)

        if response then
            local responseBody = response.readAll()
            response.close()

            local data = textutils.unserializeJSON(responseBody)
            if data and data.choices and data.choices[1] then
                local aiMessage = data.choices[1].message.content
                table.insert(history, { role = "assistant", content = aiMessage })

                -- Мигание экрана перед выводом ответа
                display.setBackgroundColor(colors.blue)
                os.sleep(0.04)
                display.setBackgroundColor(colors.black)
                drawOSHeader()

                display.setTextColor(colors.cyan)
                print("\nВерити: " .. aiMessage)
                display.setTextColor(colors.white)
            else
                display.setTextColor(colors.red)
                print("\n[ОШИБКА]: Верити сбился...")
            end
        else
            display.setTextColor(colors.red)
            print("\n[ОШИБКА]: Нет соединения с API!")
        end
    end
end
