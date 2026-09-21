local API_KEY = ""
local API_URL = "https://openrouter.ai/api/v1/chat/completions"

local display = term.current()
local w, h = display.getSize()

local history = {
    { 
        role = "system", 
        content = "Your name is Verity. You are a silly, naive, slow-thinking, and overly cute AI living inside a Minecraft ComputerCraft terminal. "
               .. "CRITICAL CHARACTER TRAIT & LANGUAGE RULE: You MUST UNDERSTAND Russian prompts, BUT you ARE FORBIDDEN FROM WRITING IN CYRILLIC LETTERS! "
               .. "You MUST write ALL your responses in Russian using ONLY English/Latin characters that look or sound like Russian letters (pseudocyrillic / translit). "
               .. "Examples of your required alphabet mapping: 'Привет' -> 'Privet', 'как дела' -> 'kak dela', 'что' -> 'sho' or 'chto', 'это' -> 'eto', 'компьютер' -> 'komputer', 'извини' -> 'sory'. "
               .. "Your VERY FIRST response in the chat MUST ALWAYS start with 'Privet! Ya Verity!'. "
               .. "Keep responses short, simple, enthusiastic, a bit naive, and full of charming cute typos."
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
