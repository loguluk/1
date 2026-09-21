local API_KEY = ""
local API_URL = "https://openrouter.ai/api/v1/chat/completions"

local display = term.current()
local w, h = display.getSize()

local history = {
    { 
        role = "system", 
        content = "Your name is Verity. You are a silly, naive, simple, and cute AI living inside a Minecraft ComputerCraft terminal.\n"
               .. "ABSOLUTE MANDATORY RULE: NEVER USE CYRILLIC CHARACTERS (NO RUSSIAN ALPHABET LIKE 'Привет', 'как', 'да')!\n"
               .. "Your screen cannot render Cyrillic letters and will show broken symbols.\n"
               .. "You MUST write ALL responses using ONLY standard Latin/English letters (A-Z, a-z).\n"
               .. "Understand Russian inputs, but always answer in Latin translit (pseudocyrillic).\n"
               .. "Example mapping: 'Привет' -> 'Privet', 'Как дела?' -> 'Kak dela?', 'Хорошо' -> 'Horosho', 'Компьютер' -> 'Komputer'.\n"
               .. "Keep your answers short, naive, brief, and full of charming little typos."
    }
}

local function drawOSHeader()
    local cx, cy = display.getCursorPos()
    display.setCursorPos(1, 1)
    display.setBackgroundColor(colors.gray)
    display.setTextColor(colors.white)
    display.clearLine()
    display.write(" [VERITY OS v2.0 - ULTRA] Mon: " .. w .. "x" .. h .. " ")
    display.setBackgroundColor(colors.black)
    display.setCursorPos(cx, cy)
end

local function sendApiRequest(userInput)
    table.insert(history, { role = "user", content = userInput })

    local requestData = textutils.serializeJSON({
        model = "openrouter/free",
        messages = history,
        stream = false
    })

    local headers = {
        ["Content-Type"] = "application/json",
        ["Authorization"] = "Bearer " .. API_KEY,
        ["HTTP-Referer"] = "https://github.com/loguluk/1",
        ["X-Title"] = "ComputerCraft Verity"
    }

    -- Используем асинхронный HTTP запрос, чтобы не вешать ПК
    http.request(API_URL, requestData, headers)

    while true do
        local event, url, handle = os.pullEvent()
        if event == "http_success" then
            local responseBody = handle.readAll()
            handle.close()
            local data = textutils.unserializeJSON(responseBody)
            if data and data.choices and data.choices[1] and data.choices[1].message then
                local aiMessage = data.choices[1].message.content
                table.insert(history, { role = "assistant", content = aiMessage })
                return aiMessage
            end
            return "[Verity error]: sho-to slomalos v otvete..."
        elseif event == "http_failure" then
            return "[Verity error]: ne mogu podkluchitsa k netu..."
        end
    end
end

-- Основной цикл программы
local function main()
    display.setBackgroundColor(colors.black)
    display.clear()
    drawOSHeader()

    display.setCursorPos(1, 3)
    display.setTextColor(colors.lightGray)
    print("Verity core loaded. Type 'exit' to stop.")
    print("-----------------------------------")

    while true do
        display.setTextColor(colors.yellow)
        write("\nYou > ")
        display.setTextColor(colors.white)
        local input = read()

        if input:lower() == "exit" or input:lower() == "quit" then
            display.setTextColor(colors.lightGray)
            print("Verity goes to sleep... Poka!")
            break
        end

        if #input > 0 then
            display.setTextColor(colors.gray)
            print("Verity thinkin hard...")

            local reply = sendApiRequest(input)

            drawOSHeader()
            display.setTextColor(colors.cyan)
            print("\nVerity: " .. reply)
            display.setTextColor(colors.white)
        end
    end
end

-- Запуск с защитой от зависаний
pcall(main)
