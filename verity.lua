local API_KEY = ""
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
                print("\n[ERROR]: Failed to parse message content.")
            end
        else
            display.setTextColor(colors.red)
            print("\n[ERROR]: HTTP Request failed.")
        end
    end
end
