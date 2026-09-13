-- ===================================================
-- ENTERTAINMENT OS V4.0 ULTRA KERNEL
-- Target: ComputerCraft Monitor & Terminal
-- ===================================================

local display = peripheral.find("monitor") or term
if display.setTextScale then display.setTextScale(0.5) end
local w, h = display.getSize()

_G.Sys = {
    mon = display,
    w = w,
    h = h,
    running = true,
    currentApp = "MENU",
    uptime = 0,
    version = "4.0.2"
}

local function drawHeader()
    display.setBackgroundColor(colors.cyan)
    display.setTextColor(colors.black)
    display.setCursorPos(1, 1)
    display.clearLine()
    display.write(" [OS V" .. _G.Sys.version .. "] ENTERTAINMENT SYSTEM")
    
    local timeStr = textutils.formatTime(os.time(), true)
    display.setCursorPos(w - string.len(timeStr) - 1, 1)
    display.write(timeStr)
end

local function drawFooter()
    display.setBackgroundColor(colors.gray)
    display.setTextColor(colors.white)
    display.setCursorPos(1, h)
    display.clearLine()
    display.write(" Touch options on screen | Press Q to exit ")
end

local function drawMenu()
    display.setBackgroundColor(colors.blue)
    display.clear()
    drawHeader()
    drawFooter()

    local menuItems = {
        {title = "[ 1 ] DOOM 3D RAYCASTER ENGINE", app = "apps/doom.lua"},
        {title = "[ 2 ] ADVANCED PAINT EDITOR",     app = "apps/paint.lua"},
        {title = "[ 3 ] SYSTEM FILE MANAGER",       app = "apps/fileman.lua"},
        {title = "[ 4 ] RETRO GAMES SUITE",         app = "apps/games.lua"},
        {title = "[ 5 ] SHUTDOWN SYSTEM",           app = "EXIT"}
    }

    local startY = 4
    for i, item in ipairs(menuItems) do
        display.setCursorPos(math.floor((w - string.len(item.title)) / 2), startY + (i * 2))
        display.setBackgroundColor(colors.lightBlue)
        display.setTextColor(colors.white)
        display.write("  " .. item.title .. "  ")
    end
end

local function launchApp(appFile)
    if appFile == "EXIT" then
        _G.Sys.running = false
        return
    end

    if fs.exists(appFile) then
        shell.run(appFile)
    else
        display.setBackgroundColor(colors.red)
        display.setTextColor(colors.white)
        display.setCursorPos(2, math.floor(h / 2))
        display.write(" ERROR: " .. appFile .. " not found! ")
        sleep(2)
    end
    drawMenu()
end

drawMenu()

local mainTimer = os.startTimer(1)

while _G.Sys.running do
    local event, p1, p2, p3 = os.pullEvent()

    if event == "timer" and p1 == mainTimer then
        _G.Sys.uptime = _G.Sys.uptime + 1
        drawHeader()
        mainTimer = os.startTimer(1)
    elseif event == "monitor_touch" or event == "mouse_click" then
        local x, y = p2, p3
        if y == 6 then launchApp("apps/doom.lua")
        elseif y == 8 then launchApp("apps/paint.lua")
        elseif y == 10 then launchApp("apps/fileman.lua")
        elseif y == 12 then launchApp("apps/games.lua")
        elseif y == 14 then launchApp("EXIT") end
    elseif event == "key" then
        if p1 == keys.one then launchApp("apps/doom.lua")
        elseif p1 == keys.two then launchApp("apps/paint.lua")
        elseif p1 == keys.three then launchApp("apps/fileman.lua")
        elseif p1 == keys.four then launchApp("apps/games.lua")
        elseif p1 == keys.five or p1 == keys.q then _G.Sys.running = false end
    end
end

display.setBackgroundColor(colors.black)
display.clear()
display.setCursorPos(1, 1)
print("OS Shutdown Successfully.")