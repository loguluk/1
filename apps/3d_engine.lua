-- ===================================================
-- ADVANCED 3D GRAPHICS ENGINE & VECTOR MATH
-- Features: 3-Axis Rotation, Wireframe Rasterizer, Mesh Library
-- ===================================================

local Engine3D = {
    selectedModel = "CUBE",
    fov = 30,
    distance = 3.5
}

-- 3D Vector Operations
function Engine3D.createVector(x, y, z)
    return {x = x or 0, y = y or 0, z = z or 0}
end

-- Complete 3D Matrix Rotation (X, Y, Z Axes)
function Engine3D.project(point3D, angleX, angleY, angleZ)
    local radX = math.rad(angleX)
    local radY = math.rad(angleY)
    local radZ = math.rad(angleZ)

    -- X-Axis
    local y1 = point3D.y * math.cos(radX) - point3D.z * math.sin(radX)
    local z1 = point3D.y * math.sin(radX) + point3D.z * math.cos(radX)
    local x1 = point3D.x

    -- Y-Axis
    local x2 = x1 * math.cos(radY) + z1 * math.sin(radY)
    local z2 = -x1 * math.sin(radY) + z1 * math.cos(radY)
    local y2 = y1

    -- Z-Axis
    local x3 = x2 * math.cos(radZ) - y2 * math.sin(radZ)
    local y3 = x2 * math.sin(radZ) + y2 * math.cos(radZ)
    local z3 = z2 + Engine3D.distance

    -- Perspective Projection Formula
    local projX = math.floor((Engine3D.fov * x3) / z3 + (_G.Sys.w / 2))
    local projY = math.floor((Engine3D.fov * y3) / z3 + (_G.Sys.h / 2))

    return projX, projY
end

-- Line Rasterization (Bresenham Algorithm)
local function drawLine(x0, y0, x1, y1, char, fg, bg)
    local dx = math.abs(x1 - x0)
    local dy = math.abs(y1 - y0)
    local sx = x0 < x1 and 1 or -1
    local sy = y0 < y1 and 1 or -1
    local err = dx - dy

    while true do
        _G.Sys.setPixel(x0, y0, char, fg, bg)
        if x0 == x1 and y0 == y1 then break end
        local e2 = 2 * err
        if e2 > -dy then err = err - dy x0 = x0 + sx end
        if e2 < dx then err = err + dx y0 = y0 + sy end
    end
end

-- 3D Mesh Geometry Library
Engine3D.Meshes = {
    CUBE = {
        nodes = {
            Engine3D.createVector(-1,-1,-1), Engine3D.createVector(1,-1,-1),
            Engine3D.createVector(1,1,-1), Engine3D.createVector(-1,1,-1),
            Engine3D.createVector(-1,-1,1), Engine3D.createVector(1,-1,1),
            Engine3D.createVector(1,1,1), Engine3D.createVector(-1,1,1)
        },
        edges = {
            {1,2},{2,3},{3,4},{4,1},{5,6},{6,7},{7,8},{8,5},{1,5},{2,6},{3,7},{4,8}
        }
    },
    PYRAMID = {
        nodes = {
            Engine3D.createVector(0, -1.2, 0),
            Engine3D.createVector(-1, 1, -1), Engine3D.createVector(1, 1, -1),
            Engine3D.createVector(1, 1, 1), Engine3D.createVector(-1, 1, 1)
        },
        edges = {
            {1,2},{1,3},{1,4},{1,5},{2,3},{3,4},{4,5},{5,2}
        }
    },
    OCTAHEDRON = {
        nodes = {
            Engine3D.createVector(0,-1.5,0), Engine3D.createVector(0,1.5,0),
            Engine3D.createVector(-1,0,0), Engine3D.createVector(1,0,0),
            Engine3D.createVector(0,0,-1), Engine3D.createVector(0,0,1)
        },
        edges = {
            {1,3},{1,4},{1,5},{1,6},{2,3},{2,4},{2,5},{2,6},
            {3,5},{5,4},{4,6},{6,3}
        }
    }
}

function Engine3D.init()
    _G.Sys.clear(colors.black)
end

function Engine3D.renderComplexMesh(rotX, rotY, rotZ)
    _G.Sys.initBuffer()
    local mesh = Engine3D.Meshes[Engine3D.selectedModel] or Engine3D.Meshes.CUBE
    local projected = {}

    for i, node in ipairs(mesh.nodes) do
        local px, py = Engine3D.project(node, rotX, rotY, rotZ)
        projected[i] = {x = px, y = py}
    end

    for _, edge in ipairs(mesh.edges) do
        local p1 = projected[edge[1]]
        local p2 = projected[edge[2]]
        drawLine(p1.x, p1.y, p2.x, p2.y, "*", colors.yellow, colors.black)
    end

    _G.Sys.drawText(2, 1, "3D RENDERER | MODEL: " .. Engine3D.selectedModel, colors.cyan, colors.black)
    _G.Sys.drawText(2, _G.Sys.h, "[SWITCH MODEL]", colors.black, colors.white)
    _G.Sys.drawExitButton()
    _G.Sys.flush()
end

function Engine3D.handleTouch(x, y)
    if y == _G.Sys.h and x <= 16 then
        if Engine3D.selectedModel == "CUBE" then Engine3D.selectedModel = "PYRAMID"
        elseif Engine3D.selectedModel == "PYRAMID" then Engine3D.selectedModel = "OCTAHEDRON"
        else Engine3D.selectedModel = "CUBE" end
    end
end

return Engine3D