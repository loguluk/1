-- ===================================================
-- TOUCH GRAPHICS PAINT FOR COMPUTERCRAFT
-- Enhanced Touch-First Interface
-- ===================================================

local display = peripheral.find("monitor") or term
if display.setTextScale then display.setTextScale(0.5) end
local w, h = display.getSize()

local currentColor = colors.red
local palette = {
    colors.black, colors.white, colors.red, colors.green,
    colors.blue, colors.yellow, colors.orange, colors.cyan
}

local paletteNames = {"BLK", "WHT", "RED", "GRN", "BLU", "YEL", "ORG", "CYN"}

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
    display.setCursorPos(w - 7, h)
    display.write("[ EXIT ]")
end

display.setBackgroundColor(colors.black)
display.clear()
drawPalette()

-- Calculate palette button positions more accurately
local colorButtonPositions = {}
for i = 1, #palette do
    colorButtonPositions[i] = {x1 = 8 + (i - 1) * 2, x2 = 8 + (i - 1) * 2 + 1}
end

local exitBtn = {x1 = w - 7, x2 = w, y = h}

local drawing = true
while drawing do
    local event, p1, x, y = os.pullEvent()

    if event == "monitor_touch" or event == "mouse_click" or event == "mouse_drag" then
        if y == h then
            if x >= exitBtn.x1 and x <= exitBtn.x2 then
                drawing = false
            else
                -- Check which color was clicked
                for i, btn in ipairs(colorButtonPositions) do
                    if x >= btn.x1 and x <= btn.x2 then
                        currentColor = palette[i]
                        break
                    end
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

display.setBackgroundColor(colors.black)
display.clear()