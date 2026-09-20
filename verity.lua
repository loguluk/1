local API_KEY = "YOUR_DEEPSEEK_API_KEY"
local API_URL = "https://api.deepseek.com/chat/completions"

if API_KEY == "YOUR_DEEPSEEK_API_KEY" then
    error("Укажите ваш API_KEY на первой строчке кода!")
end

-- Системная инструкция персонажа
local history = {
    { 
        role = "system", 
        content = "Тебя зовут Верити. Ты живешь внутри компьютера в Minecraft. Твоё самое первое сообщение ВСЕГДА должно начинаться со слов 'Привет, я Верити'. Ты немного глуповат, соображаешь медленно, отвечаешь просто и наивно. Делай в тексте небольшие, но понятные орфографические ошибки или опечатки (например, 'превет', 'шо', 'тута', 'щас', 'зачемь', 'компютер'), но так, чтобы смысл ответа оставался понятен. Не пиши слишком умные и длинные фразы." 
    }
}

-- Инициализация экрана
term.clear()
local w, h = term.getSize()

-- Функция симуляции графического сбоя/глюка ПК
local function glitchEffect()
    if math.random(1, 3) == 1 then -- Срабатывает случайным образом
        local gx = math.random(1, w - 5)
        local gy = math.random(2, h - 2)
        term.setCursorPos(gx, gy)
        term.setBackgroundColor(colors.red)
        term.setTextColor(colors.yellow)
        term.write("ERR#404")
        os.sleep(0.08)
        term.setBackgroundColor(colors.black)
    end
end

-- Функция отрисовки графической шапки интерфейса
local function drawHeader()
    term.setBackgroundColor(colors.gray)
    term.setTextColor(colors.white)
    term.setCursorPos(1, 1)
    term.clearLine()
    term.write(" [VERITY OS v0.1] - Status: OK? ")
    term.setBackgroundColor(colors.black)
end

drawHeader()
term.setCursorPos(1, 3)
term.setTextColor(colors.lightGray)
print("Система запущена. Напишите что-нибудь Верити...")
print("------------------------------------------------")

while true do
    glitchEffect()

    -- Ввод пользователя
    term.setTextColor(colors.yellow)
    term.write("\nВы > ")
    term.setTextColor(colors.white)
    local input = read()

    if input:lower() == "exit" or input:lower() == "quit" then
        term.setTextColor(colors.lightGray)
        print("Верити выключился...")
        break
    end

    if #input > 0 then
        table.insert(history, { role = "user", content = input })

        term.setTextColor(colors.gray)
        print("Верити думати... [====  ]")
        glitchEffect()

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

                -- Эффект лёгкого подмигивания экрана перед ответом
                term.setBackgroundColor(colors.blue)
                os.sleep(0.05)
                term.setBackgroundColor(colors.black)
                drawHeader()

                term.setTextColor(colors.cyan)
                print("\nВерити: " .. aiMessage)
                term.setTextColor(colors.white)
            else
                term.setTextColor(colors.red)
                print("\n[ОШИБКА]: Верити запутался в ответе...")
            end
        else
            term.setTextColor(colors.red)
            print("\n[ОШИБКА]: Нет связи с Верити (проверьте интернет или ключ)")
        end
    end
end
