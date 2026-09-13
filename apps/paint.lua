-- ===================================================
-- TOUCH GRAPHICS PAINT FOR COMPUTERCRAFT
-- ===================================================

local display = peripheral.find("monitor") or term
if display.setTextScale then display.setTextScale(0.5) end
local w, h = display.getSize()

local currentColor = colors.red
local palette = {
    colors.black, colors.white, colors.red, colors.green,
    colors.blue, colors.yellow, colors.orange, colors.cyan
}

local function drawPalette()
    display.setBackgroundColor(colors.gray)
    display.setCursorPos(1, h)
    display.clearLine()
    display.write("COLOR: ")
    
    for i, col in ipairs(palette) do
        display.setBackgroundColor(col)
        display.write("  ")
    end
    
    display.setBackgroundColor(colors.red)
    display.setTextColor(colors.white)
    display.setCursorPos(w - 5, h)
    display.write("[EXIT]")
end

display.setBackgroundColor(colors.black)
display.clear()
drawPalette()

local drawing = true
while drawing do
    local event, p1, x, y = os.pullEvent()

    if event == "monitor_touch" or event == "mouse_click" or event == "mouse_drag" then
        if y == h then
            if x >= w - 5 then
                drawing = false
            else
                local colIdx = math.floor((x - 8) / 2) + 1
                if palette[colIdx] then
                    currentColor = palette[colIdx]
                end
            end
        else
            display.setBackgroundColor(currentColor)
            display.setCursorPos(x, y)
            display.write(" ")
        end
    elseif event == "key" and p1 == keys.q then
        drawing = false
    end
end