local API_KEY = "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"
local API_URL = "https://openrouter.ai/api/v1/chat/completions"

local display = term.current()
display.clear()
local w, h = display.getSize()

local history = {
    { 
        role = "system", 
        content = "Your name is Verity. You live inside a Minecraft ComputerCraft computer. Your VERY FIRST response must ALWAYS start with 'Privet, I am Verity'. You are a bit silly, slow-thinking, simple, and naive. Make small, clear typos and misspellings in your replies (for example: 'privet', 'sho', 'wot', 'komputer', 'lok', 'sory'), but keep the meaning understandable. Keep your answers brief and simple." 
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
print("Connected to OpenRouter. Verity ready!")
print("Type 'exit' to quit.")
print("-----------------------------------")

while true do
    triggerScreenGlitch()

    display.setTextColor(colors.yellow)
    write("\nYou > ")
    display.setTextColor(colors.white)
    local input = read()

    if input:lower() == "exit" or input:lower() == "quit" then
        display.setTextColor(colors.lightGray)
        print("Verity shutting down...")
        break
    end

    if #input > 0 then
        table.insert(history, { role = "user", content = input })

        display.setTextColor(colors.gray)
        print("Verity thinkin...")
        triggerScreenGlitch()

        local requestData = textutils.serializeJSON({
            model = "google/gemma-2-9b-it:free",
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
            if data and data.choices and data.choices[1] then
                local aiMessage = data.choices[1].message.content
                table.insert(history, { role = "assistant", content = aiMessage })

                display.setBackgroundColor(colors.blue)
                os.sleep(0.04)
                display.setBackgroundColor(colors.black)
                drawOSHeader()

                display.setTextColor(colors.cyan)
                print("\nVerity: " .. aiMessage)
                display.setTextColor(colors.white)
            else
                display.setTextColor(colors.red)
                print("\n[ERROR]: Failed to parse API response.")
            end
        else
            display.setTextColor(colors.red)
            print("\n[ERROR]: HTTP Request failed! Check API key or CC config.")
        end
    end
end
