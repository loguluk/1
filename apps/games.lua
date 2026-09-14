-- ===================================================
-- RETRO GAMES SUITE (SNAKE, MATRIX & TETRIS)
-- Touch-First Interface
-- ===================================================

local display = peripheral.find("monitor") or term
if display.setTextScale then display.setTextScale(0.5) end
local w, h = display.getSize()

local function runSnake()
    local snake = {{x = 5, y = 5}, {x = 4, y = 5}, {x = 3, y = 5}}
    local food = {x = 12, y = 8}
    local dir = "RIGHT"
    local nextDir = "RIGHT"
    local score = 0
    local alive = true

    local timer = os.startTimer(0.1)
    
    -- Touch button positions for Snake
    local upBtn = {x1 = w/2 - 2, x2 = w/2 + 2, y = 3}
    local leftBtn = {x1 = w/2 - 6, x2 = w/2 - 3, y = 5}
    local downBtn = {x1 = w/2 - 2, x2 = w/2 + 2, y = 7}
    local rightBtn = {x1 = w/2 + 3, x2 = w/2 + 6, y = 5}
    local exitBtn = {x1 = w - 7, x2 = w, y = h}

    local function drawGame()
        display.setBackgroundColor(colors.black)
        display.clear()

        display.setCursorPos(2, 1)
        display.setTextColor(colors.yellow)
        display.write("SNAKE SCORE: " .. score)

        display.setBackgroundColor(colors.red)
        display.setCursorPos(food.x, food.y)
        display.write(" ")

        display.setBackgroundColor(colors.lime)
        for _, seg in ipairs(snake) do
            display.setCursorPos(seg.x, seg.y)
            display.write(" ")
        end
        
        -- Draw touch buttons
        display.setBackgroundColor(colors.gray)
        display.setTextColor(colors.white)
        display.setCursorPos(upBtn.x1, upBtn.y)
        display.write("  [^]  ")
        display.setCursorPos(leftBtn.x1, leftBtn.y)
        display.write("[<]")
        display.setCursorPos(downBtn.x1, downBtn.y)
        display.write("  [v]  ")
        display.setCursorPos(rightBtn.x1, rightBtn.y)
        display.write("[>]")
        
        display.setBackgroundColor(colors.red)
        display.setCursorPos(exitBtn.x1, exitBtn.y)
        display.write("[ EXIT ]")
    end

    while alive do
        local event, p1, p2, p3 = os.pullEvent()

        if event == "timer" and p1 == timer then
            dir = nextDir
            local head = {x = snake[1].x, y = snake[1].y}
            if dir == "UP" then head.y = head.y - 1
            elseif dir == "DOWN" then head.y = head.y + 1
            elseif dir == "LEFT" then head.x = head.x - 1
            elseif dir == "RIGHT" then head.x = head.x + 1 end

            if head.x < 1 or head.x > w or head.y < 2 or head.y > h - 1 then
                alive = false
            end

            table.insert(snake, 1, head)
            if head.x == food.x and head.y == food.y then
                score = score + 10
                food = {x = math.random(2, w - 2), y = math.random(3, h - 2)}
            else
                table.remove(snake)
            end

            drawGame()
            timer = os.startTimer(0.1)
        elseif event == "key" then
            if p1 == keys.up and dir ~= "DOWN" then nextDir = "UP"
            elseif p1 == keys.down and dir ~= "UP" then nextDir = "DOWN"
            elseif p1 == keys.left and dir ~= "RIGHT" then nextDir = "LEFT"
            elseif p1 == keys.right and dir ~= "LEFT" then nextDir = "RIGHT"
            elseif p1 == keys.q then alive = false end
        elseif event == "monitor_touch" or event == "mouse_click" then
            local x, y = p2, p3
            if x >= upBtn.x1 and x <= upBtn.x2 and y == upBtn.y and dir ~= "DOWN" then
                nextDir = "UP"
            elseif x >= leftBtn.x1 and x <= leftBtn.x2 and y == leftBtn.y and dir ~= "RIGHT" then
                nextDir = "LEFT"
            elseif x >= downBtn.x1 and x <= downBtn.x2 and y == downBtn.y and dir ~= "UP" then
                nextDir = "DOWN"
            elseif x >= rightBtn.x1 and x <= rightBtn.x2 and y == rightBtn.y and dir ~= "LEFT" then
                nextDir = "RIGHT"
            elseif x >= exitBtn.x1 and x <= exitBtn.x2 and y == exitBtn.y then
                alive = false
            end
        end
    end
end

local function runMatrix()
    display.setBackgroundColor(colors.black)
    display.clear()
    
    local cols = {}
    for i = 1, w do cols[i] = math.random(-h, 0) end

    local active = true
    local timer = os.startTimer(0.05)
    local exitBtn = {x1 = w - 7, x2 = w, y = 1}

    while active do
        local event, p1, p2, p3 = os.pullEvent()
        if event == "timer" and p1 == timer then
            for i = 1, w do
                cols[i] = cols[i] + 1
                if cols[i] > 0 and cols[i] <= h - 1 then
                    display.setCursorPos(i, cols[i])
                    display.setTextColor(colors.green)
                    display.write(string.char(math.random(33, 126)))
                end
                if cols[i] > h - 1 then cols[i] = math.random(-5, 0) end
            end
            
            -- Draw EXIT button
            display.setBackgroundColor(colors.red)
            display.setTextColor(colors.white)
            display.setCursorPos(exitBtn.x1, exitBtn.y)
            display.write("[ EXIT ]")
            
            timer = os.startTimer(0.05)
        elseif event == "key" and p1 == keys.q then
            active = false
        elseif event == "monitor_touch" or event == "mouse_click" then
            local x, y = p2, p3
            if x >= exitBtn.x1 and x <= exitBtn.x2 and y == exitBtn.y then
                active = false
            end
        end
    end
end

local function runTetris()
    local gridW, gridH = 10, 15
    local grid = {}
    for y = 1, gridH do
        grid[y] = {}
        for x = 1, gridW do
            grid[y][x] = 0
        end
    end

    local pieces = {
        {{1, 1, 1, 1}},
        {{1, 1}, {1, 1}},
        {{0, 1, 1}, {1, 1, 0}},
        {{1, 1, 0}, {0, 1, 1}},
        {{1, 0, 0}, {1, 1, 1}},
        {{0, 0, 1}, {1, 1, 1}},
        {{0, 1, 0}, {1, 1, 1}}
    }

    local function getPiece()
        return pieces[math.random(1, #pieces)]
    end

    local currentPiece = getPiece()
    local posX, posY = 5, 1
    local score = 0
    local gameOver = false
    local timer = os.startTimer(0.5)

    local function canPlace(px, py, piece)
        for y, row in ipairs(piece) do
            for x, cell in ipairs(row) do
                if cell == 1 then
                    local gx, gy = px + x - 1, py + y - 1
                    if gx < 1 or gx > gridW or gy > gridH then
                        return false
                    end
                    if gy > 0 and grid[gy][gx] == 1 then
                        return false
                    end
                end
            end
        end
        return true
    end

    local function placePiece(px, py, piece)
        for y, row in ipairs(piece) do
            for x, cell in ipairs(row) do
                if cell == 1 then
                    local gx, gy = px + x - 1, py + y - 1
                    if gy > 0 and gy <= gridH then
                        grid[gy][gx] = 1
                    end
                end
            end
        end
    end

    local function clearLines()
        local cleared = 0
        for y = gridH, 1, -1 do
            local full = true
            for x = 1, gridW do
                if grid[y][x] == 0 then
                    full = false
                    break
                end
            end
            if full then
                cleared = cleared + 1
                table.remove(grid, y)
                table.insert(grid, 1, {})
                for x = 1, gridW do
                    grid[1][x] = 0
                end
            end
        end
        return cleared
    end

    local function drawGame()
        display.setBackgroundColor(colors.black)
        display.clear()
        display.setTextColor(colors.cyan)
        display.setCursorPos(2, 1)
        display.write("TETRIS | Score: " .. score)

        local startX = 2
        for y = 1, gridH do
            display.setCursorPos(startX, y + 1)
            display.setTextColor(colors.white)
            display.write("|")
            for x = 1, gridW do
                if grid[y][x] == 1 then
                    display.setTextColor(colors.lime)
                    display.write("#")
                else
                    display.setTextColor(colors.white)
                    display.write(".")
                end
            end
            display.setTextColor(colors.white)
            display.write("|")
        end
    end

    while not gameOver do
        local event, p1 = os.pullEvent()

        if event == "timer" and p1 == timer then
            if canPlace(posX, posY + 1, currentPiece) then
                posY = posY + 1
            else
                placePiece(posX, posY, currentPiece)
                local cleared = clearLines()
                score = score + (cleared * 100)
                currentPiece = getPiece()
                posX, posY = 5, 1
                if not canPlace(posX, posY, currentPiece) then
                    gameOver = true
                end
            end
            drawGame()
            timer = os.startTimer(0.5)
        elseif event == "key" then
            if p1 == keys.left and canPlace(posX - 1, posY, currentPiece) then
                posX = posX - 1
            elseif p1 == keys.right and canPlace(posX + 1, posY, currentPiece) then
                posX = posX + 1
            elseif p1 == keys.down then
                if canPlace(posX, posY + 1, currentPiece) then
                    posY = posY + 1
                end
            elseif p1 == keys.q then
                gameOver = true
            end
            drawGame()
        end
    end
end

local function showMenu()
    display.setBackgroundColor(colors.gray)
    display.clear()
    display.setTextColor(colors.white)
    
    -- Title
    display.setCursorPos(2, 1)
    display.write("=== RETRO GAMES SUITE ===")
    
    -- Game options with touch-friendly buttons
    display.setCursorPos(4, 4)
    display.setBackgroundColor(colors.green)
    display.write("  [ 1 ] PLAY SNAKE  ")
    
    display.setCursorPos(4, 6)
    display.setBackgroundColor(colors.blue)
    display.write("[ 2 ] MATRIX RAIN")
    
    display.setCursorPos(4, 8)
    display.setBackgroundColor(colors.orange)
    display.write("  [ 3 ] PLAY TETRIS  ")
    
    display.setCursorPos(4, 10)
    display.setBackgroundColor(colors.red)
    display.write("  [ Q ] EXIT MENU  ")
    
    -- Button positions
    return {
        snake = {x1 = 4, x2 = 22, y = 4},
        matrix = {x1 = 4, x2 = 20, y = 6},
        tetris = {x1 = 4, x2 = 22, y = 8},
        exit = {x1 = 4, x2 = 20, y = 10}
    }
end

local buttons = showMenu()
local waiting = true

while waiting do
    local event, p1, p2, p3 = os.pullEvent()
    if event == "key" then
        if p1 == keys.one then
            runSnake()
            buttons = showMenu()
        elseif p1 == keys.two then
            runMatrix()
            buttons = showMenu()
        elseif p1 == keys.three then
            runTetris()
            buttons = showMenu()
        elseif p1 == keys.q then
            waiting = false
        end
    elseif event == "monitor_touch" or event == "mouse_click" then
        local x, y = p2, p3
        if y == buttons.snake.y and x >= buttons.snake.x1 and x <= buttons.snake.x2 then
            runSnake()
            buttons = showMenu()
        elseif y == buttons.matrix.y and x >= buttons.matrix.x1 and x <= buttons.matrix.x2 then
            runMatrix()
            buttons = showMenu()
        elseif y == buttons.tetris.y and x >= buttons.tetris.x1 and x <= buttons.tetris.x2 then
            runTetris()
            buttons = showMenu()
        elseif y == buttons.exit.y and x >= buttons.exit.x1 and x <= buttons.exit.x2 then
            waiting = false
        end
    end
end

display.setBackgroundColor(colors.black)
display.clear()