-- Master Factory Controller (English Version)
-- Connected Turtle: turtle_21 (ID: 104)

local RECIPE_FILE = "recipes.json"

local monitor = peripheral.find("monitor")
if monitor then
    monitor.setTextScale(0.5)
    monitor.clear()
else
    print("Warning: Monitor peripheral not found!")
end

local devices = {
    depotPress = "create:depot_14",
    depotArm   = "create:depot_16",
    deployer   = "create:deployer_9",
    basinPress = "create:basin_10",
    basinMixer = "create:basin_11",
    turtle     = "turtle_21"
}

local recipes = {}

function loadRecipes()
    if fs.exists(RECIPE_FILE) then
        local f = fs.open(RECIPE_FILE, "r")
        local data = f.readAll()
        f.close()
        recipes = textutils.unserializeJSON(data) or {}
    end
end

function saveRecipes()
    local f = fs.open(RECIPE_FILE, "w")
    f.write(textutils.serializeJSON(recipes))
    f.close()
end

loadRecipes()

function drawButton(x, y, w, h, bg, text)
    if not monitor then return end
    monitor.setBackgroundColor(bg)
    monitor.setTextColor(colors.white)
    for i = 0, h - 1 do
        monitor.setCursorPos(x, y + i)
        monitor.write(string.rep(" ", w))
    end
    monitor.setCursorPos(x + 1, y + math.floor(h / 2))
    monitor.write(text)
    monitor.setBackgroundColor(colors.black)
end

function updateMonitor()
    if not monitor then return end
    monitor.setBackgroundColor(colors.black)
    monitor.clear()

    monitor.setCursorPos(2, 2)
    monitor.setTextColor(colors.yellow)
    monitor.write("=== AUTO-FACTORY CONTROLLER (TURTLE 104) ===")

    monitor.setCursorPos(2, 4)
    monitor.setTextColor(colors.cyan)
    monitor.write("DEVICE STATUS:")

    local statusY = 5
    for label, name in pairs(devices) do
        monitor.setCursorPos(4, statusY)
        if peripheral.isPresent(name) then
            monitor.setTextColor(colors.green)
            monitor.write("[+] " .. label .. " (" .. name .. ")")
        else
            monitor.setTextColor(colors.red)
            monitor.write("[-] " .. label .. " (OFFLINE)")
        end
        statusY = statusY + 1
    end

    monitor.setCursorPos(2, 12)
    monitor.setTextColor(colors.orange)
    monitor.write("SAVED RECIPES (" .. #recipes .. "):")

    for i, r in ipairs(recipes) do
        if i <= 5 then
            monitor.setCursorPos(4, 12 + i)
            monitor.setTextColor(colors.lightBlue)
            monitor.write(i .. ". " .. r.name .. " -> " .. (r.output or "Unknown"))
        end
    end

    drawButton(2, 19, 22, 3, colors.blue, " [1] RECORD RECIPE ")
    drawButton(26, 19, 22, 3, colors.gray, " [2] REFRESH ")
end

function snapshotInventories()
    local snap = {}
    for label, devName in pairs(devices) do
        if peripheral.isPresent(devName) then
            local p = peripheral.wrap(devName)
            if p and p.list then
                snap[devName] = {}
                local items = p.list()
                for slot, item in pairs(items) do
                    snap[devName][slot] = { name = item.name, count = item.count }
                end
            end
        end
    end
    return snap
end

function recordRecipeInteractive()
    term.clear()
    term.setCursorPos(1, 1)
    print("=== RECORD NEW RECIPE ===")
    write("Enter recipe name: ")
    local recipeName = read()
    if recipeName == "" then return end

    print("\n1. Clear containers or place them in initial state.")
    print("Press ENTER to capture BEFORE snapshot...")
    read()
    local beforeSnap = snapshotInventories()

    print("\n2. Place ingredients in basins/depots or turtle 3x3 grid.")
    print("Press ENTER to capture AFTER snapshot...")
    read()
    local afterSnap = snapshotInventories()

    local newRecipe = {
        name = recipeName,
        grid3x3 = {},
        inputs = {},
        outputs = {}
    }

    if afterSnap[devices.turtle] then
        for slot = 1, 9 do
            if afterSnap[devices.turtle][slot] then
                newRecipe.grid3x3[slot] = afterSnap[devices.turtle][slot]
            end
        end
    end

    for devName, slots in pairs(afterSnap) do
        for slot, item in pairs(slots) do
            local prevCount = (beforeSnap[devName] and beforeSnap[devName][slot]) and beforeSnap[devName][slot].count or 0
            local diff = item.count - prevCount

            if diff > 0 then
                table.insert(newRecipe.outputs, { device = devName, item = item.name, count = diff })
                newRecipe.output = item.name
            elseif diff < 0 then
                table.insert(newRecipe.inputs, { device = devName, item = item.name, count = math.abs(diff) })
            end
        end
    end

    table.insert(recipes, newRecipe)
    saveRecipes()
    updateMonitor()

    print("\nRecipe '" .. recipeName .. "' saved successfully to recipes.json!")
    sleep(2)
end

updateMonitor()

parallel.waitForAny(
    function()
        while true do
            local event, side, x, y = os.pullEvent("monitor_touch")
            if y >= 19 and y <= 21 then
                if x >= 2 and x <= 24 then
                    recordRecipeInteractive()
                elseif x >= 26 and x <= 48 then
                    updateMonitor()
                end
            end
        end
    end,

    function()
        while true do
            term.clear()
            term.setCursorPos(1, 1)
            print("=================================")
            print("  FACTORY CONTROLLER (TURTLE 104)")
            print("=================================")
            print("1. Record new recipe (Before/After)")
            print("2. Refresh monitor display")
            print("3. View recipes status")
            print("---------------------------------")
            write("Select option: ")

            local choice = read()
            if choice == "1" then
                recordRecipeInteractive()
            elseif choice == "2" then
                updateMonitor()
            elseif choice == "3" then
                print("\nTotal stored recipes: " .. #recipes)
                sleep(2)
            end
        end
    end
)
