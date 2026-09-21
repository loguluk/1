local API_KEY = ""
local API_URL = "https://openrouter.ai/api/v1/chat/completions"

local display = term.current()
display.clear()
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
    display.write(" [VERITY OS v2.0 - ULTRA EDITION] Mon: " .. w .. "x" .. h .. " ")
    display.setBackgroundColor(colors.black)
    display.setCursorPos(cx, cy)
end

display.setBackgroundColor(colors.black)
display.clear()
drawOSHeader()

display.setCursorPos(1, 3)
display.setTextColor(colors.lightGray)
print("Verity core activated. Type 'exit' to stop.")
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
        table.insert(history, { role = "user", content = input })

        display.setTextColor(colors.gray)
        print("Verity thinkin hard...")

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

        local response = http.post(API_URL, requestData, headers)

        if response then
            local responseBody = response.readAll()
            response.close()

            local data = textutils.unserializeJSON(responseBody)
            if data and data.choices and data.choices[1] and data.choices[1].message then
                local aiMessage = data.choices[1].message.content
                table.insert(history, { role = "assistant", content = aiMessage })

                drawOSHeader()
                display.setTextColor(colors.cyan)
                print("\nVerity: " .. aiMessage)
                display.setTextColor(colors.white)
            else
                display.setTextColor(colors.red)
                print("\n[ERROR]: Failed to parse response.")
            end
        else
            display.setTextColor(colors.red)
            print("\n[ERROR]: HTTP Request failed.")
        end
    end
end
