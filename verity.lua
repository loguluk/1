local API_KEY = "ВАШ_КЛЮЧ_ОТ_OPENROUTER"
local API_URL = "https://openrouter.ai/api/v1/chat/completions"

local display = term.current()
display.clear()
local w, h = display.getSize()

local history = {
    { 
        role = "system", 
        content = "Тебя зовут Верити. Ты живешь внутри компьютера в Minecraft ComputerCraft. Твоё самое первое сообщение ВСЕГДА должно начинаться со слов 'Привет, я Верити'. Ты немного глуповат, соображаешь медленно, отвечаешь просто и наивно. Делай в тексте небольшие, но понятные орфографические ошибки или опечатки (например, 'превет', 'шо', 'тута', 'щас', 'зачемь', 'компютер'), но так, чтобы смысл ответа оставался понятен. Не пиши слишком умные и длинные фразы." 
    }
}

local function triggerScreenGlitch()
    if math.random(1, 3) == 1 then
        local rx = math.random(1, math.max(1, w - 4))
        local ry = math.random(2, math.max(2, h - 1))
        local cx, cy = display.getCursorPos()
        
        display.setCursorPos(rx, ry)
        display.setBackgroundColor(colors.red)
        display.setTextColor(colors.yellow)
        display.write("ERR#404")
        os.sleep(0.06)
        
        display.setBackgroundColor(colors.black)
        display.setTextColor(colors.white)
        display.setCursorPos(cx, cy)
    end
end

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

display.setBackgroundColor(colors.black)
display.clear()
drawOSHeader()

display.setCursorPos(1, 3)
display.setTextColor(colors.lightGray)
print("Подключено к OpenRouter. Верити готов!")
print("-----------------------------------")

while true do
    triggerScreenGlitch()

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

        local requestData = textutils.serializeJSON({
            model = "openrouter/free",
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

                display.setBackgroundColor(colors.blue)
                os.sleep(0.04)
                display.setBackgroundColor(colors.black)
                drawOSHeader()

                display.setTextColor(colors.cyan)
                print("\nВерити: " .. aiMessage)
                display.setTextColor(colors.white)
            else
                display.setTextColor(colors.red)
                print("\n[ОШИБКА]: Не удалось распарсить ответ API.")
            end
        else
            display.setTextColor(colors.red)
            print("\n[ОШИБКА]: Ошибка HTTP! Проверьте ключ или конфиг CC.")
        end
    end
end
