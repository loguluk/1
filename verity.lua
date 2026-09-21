local API_KEY = ""
local API_URL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=" .. API_KEY

local display = term.current()
display.clear()
local w, h = display.getSize()

local systemPrompt = "Your name is Verity. You live inside a Minecraft ComputerCraft computer. Your VERY FIRST response must ALWAYS start with 'Privet, I am Verity'. You are a bit silly, slow-thinking, simple, and naive. Make small, clear typos and misspellings in your replies (for example: 'privet', 'sho', 'wot', 'komputer', 'lok', 'sory'), but keep the meaning understandable. Keep your answers brief and simple."

local history = {
    {
        role = "user",
        parts = { { text = systemPrompt } }
    },
    {
        role = "model",
        parts = { { text = "Privet, I am Verity! Wot u want?" } }
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
print("Connected to Google Gemini API. Verity ready!")
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
        table.insert(history, {
            role = "user",
            parts = { { text = input } }
        })

        display.setTextColor(colors.gray)
        print("Verity thinkin...")
        triggerScreenGlitch()

        local requestData = textutils.serializeJSON({
            contents = history
        })

        local headers = {
            ["Content-Type"] = "application/json"
        }

        local response = http.post(API_URL, requestData, headers)

        if response then
            local responseBody = response.readAll()
            response.close()

            local data = textutils.unserializeJSON(responseBody)
            if data and data.candidates and data.candidates[1] and data.candidates[1].content then
                local aiMessage = data.candidates[1].content.parts[1].text
                
                table.insert(history, {
                    role = "model",
                    parts = { { text = aiMessage } }
                })

                display.setBackgroundColor(colors.blue)
                os.sleep(0.04)
                display.setBackgroundColor(colors.black)
                drawOSHeader()

                display.setTextColor(colors.cyan)
                print("\nVerity: " .. aiMessage)
                display.setTextColor(colors.white)
            else
                display.setTextColor(colors.red)
                print("\n[ERROR]: Failed to parse Gemini response.")
            end
        else
            display.setTextColor(colors.red)
            print("\n[ERROR]: HTTP Request failed! Check API key or CC domain config.")
        end
    end
end
