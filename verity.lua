local API_KEY = ""
local API_URL = "https://openrouter.ai/api/v1/chat/completions"

local display = term.current()
local w, h = display.getSize()

-- Системный промпт для жесткого ограничения на кириллицу
local history = {
    { 
        role = "system", 
        content = "Your name is Verity. You live inside a Minecraft ComputerCraft terminal.\n"
               .. "CRITICAL RULE: YOU ARE STRICTLY FORBIDDEN FROM WRITING ANY CYRILLIC/RUSSIAN CHARACTERS (LIKE 'Привет', 'как')!\n"
               .. "The terminal CANNOT render Cyrillic letters and will crash/display corrupted symbols.\n"
               .. "You MUST write ALL responses using ONLY standard ASCII English/Latin characters (A-Z, a-z).\n"
               .. "Understand Russian input perfectly, but respond exclusively in Latin transliteration (pseudocyrillic).\n"
               .. "Examples: 'Привет' -> 'Privet', 'Как дела?' -> 'Kak dela?', 'Хорошо' -> 'Horosho', 'что' -> 'sho'.\n"
               .. "Your very first response MUST start with 'Privet! Ya Verity!'. Keep replies brief, silly, naive, and cute with small typos."
    }
}

-- Фильтр, задерживающий любые не-ASCII символы (защита от кракозябр)
local function sanitizeText(text)
    if not text then return "" end
    return text:gsub("[^\32-\126\n]", "")
end

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

-- Асинхронный запрос к API OpenRouter
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

    local ok, err = http.request(API_URL, requestData, headers)
    if not ok then
        return "[Verity error]: HTTP Request failed to initiate: " .. tostring(err)
    end

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

local function main()
    display.setBackgroundColor(colors.black)
    display.clear()
    drawOSHeader()

    display.setCursorPos(1, 3)
    display.setTextColor(colors.lightGray)
    print("Verity core activated! Type 'exit' to quit.")
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
            local cleanReply = sanitizeText(reply)

            drawOSHeader()
            display.setTextColor(colors.cyan)
            print("\nVerity: " .. cleanReply)
            display.setTextColor(colors.white)
        end
    end
end

pcall(main)
