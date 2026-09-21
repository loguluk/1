local API_KEY = ""
local API_URL = "https://openrouter.ai/api/v1/chat/completions"

local display = term.current()
local w, h = display.getSize()

local history = {
    { 
        role = "system", 
        content = "Your name is Verity. You live inside a Minecraft ComputerCraft terminal.\n"
               .. "CRITICAL RULE: YOU ARE STRICTLY FORBIDDEN FROM WRITING ANY CYRILLIC/RUSSIAN CHARACTERS!\n"
               .. "You MUST write ALL responses using ONLY standard ASCII English/Latin characters (A-Z, a-z).\n"
               .. "Understand Russian input perfectly, but respond exclusively in short Latin translit (pseudocyrillic).\n"
               .. "Examples: 'Привет' -> 'Privet', 'Как дела?' -> 'Kak dela?'.\n"
               .. "Keep replies VERY SHORT (1 sentence maximum), silly, naive, and cute with small typos."
    }
}

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
    display.write(" [VERITY OS v2.2 - TURBO] Mon: " .. w .. "x" .. h .. " ")
    display.setBackgroundColor(colors.black)
    display.setCursorPos(cx, cy)
end

local function sendApiRequest(userInput)
    table.insert(history, { role = "user", content = userInput })

    local requestData = textutils.serializeJSON({
        model = "qwen/qwen-2.5-coder-32b-instruct:free",
        messages = history,
        max_tokens = 60, -- Минимальный лимит для максимальной скорости
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
        return "[Verity error]: Request failed: " .. tostring(err)
    end

    local timerID = os.startTimer(0.3)
    local dots = { "[.  ]", "[.. ]", "[...]" }
    local dotIdx = 1

    while true do
        local event, p1, p2 = os.pullEvent()
        
        if event == "timer" and p1 == timerID then
            -- Анимация загрузки
            local cx, cy = display.getCursorPos()
            display.setTextColor(colors.gray)
            display.write("\rVerity thinkin " .. dots[dotIdx])
            dotIdx = (dotIdx % 3) + 1
            timerID = os.startTimer(0.3)
            
        elseif event == "http_success" then
            local responseBody = p2.readAll()
            p2.close()
            local data = textutils.unserializeJSON(responseBody)
            if data and data.choices and data.choices[1] and data.choices[1].message then
                local aiMessage = data.choices[1].message.content
                table.insert(history, { role = "assistant", content = aiMessage })
                return aiMessage
            end
            return "[Verity error]: bad response..."
            
        elseif event == "http_failure" then
            return "[Verity error]: connection timeout..."
        end
    end
end

local function main()
    display.setBackgroundColor(colors.black)
    display.clear()
    drawOSHeader()

    display.setCursorPos(1, 3)
    display.setTextColor(colors.lightGray)
    print("Verity core loaded (TURBO MODE)! Type 'exit' to quit.")
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
