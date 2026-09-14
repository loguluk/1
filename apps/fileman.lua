-- ===================================================
-- SYSTEM FILE MANAGER MODULE (Touch-Enabled)
-- ===================================================

local display = peripheral.find("monitor") or term
if display.setTextScale then display.setTextScale(0.5) end
local w, h = display.getSize()

local function drawFileList()
    display.setBackgroundColor(colors.blue)
    display.clear()
    
    display.setCursorPos(1, 1)
    display.setBackgroundColor(colors.cyan)
    display.setTextColor(colors.black)
    display.clearLine()
    display.write(" FILE MANAGER - DIR: /")

    local files = fs.list("")
    for i, file in ipairs(files) do
        if i > h - 4 then break end
        display.setCursorPos(2, i + 2)
        display.setBackgroundColor(colors.blue)
        if fs.isDir(file) then
            display.setTextColor(colors.yellow)
            display.write("[DIR]  " .. file)
        else
            display.setTextColor(colors.white)
            display.write("[FILE] " .. file .. " (" .. fs.getSize(file) .. "b)")
        end
    end

    display.setCursorPos(1, h)
    display.setBackgroundColor(colors.gray)
    display.setTextColor(colors.white)
    display.clearLine()
    display.write(" Touch to refresh")
    
    display.setBackgroundColor(colors.red)
    display.setTextColor(colors.white)
    display.setCursorPos(w - 7, h)
    display.write("[ EXIT ]")
end

drawFileList()

local active = true
while active do
    local event, p1, x, y = os.pullEvent()
    if event == "monitor_touch" or event == "mouse_click" then
        if y == h and x >= w - 7 then
            active = false
        else
            drawFileList()
        end
    elseif event == "key" and p1 == keys.q then
        active = false
    end
end

display.setBackgroundColor(colors.black)
display.clear()