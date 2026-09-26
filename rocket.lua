-- Автопоиск периферии (чтобы подхватил даже если изменится номер _0/_1)
local function getPeripheral(type_pattern)
    for _, name in ipairs(peripheral.getNames()) do
        if name:find(type_pattern) then
            return peripheral.wrap(name), name
        end
    end
    return nil, nil
end

local gyro, gyro_name = getPeripheral("gimbal")
local altimeter, alt_name = getPeripheral("altitude")

local thrusters = {
    FL = peripheral.wrap("liquid_vector_thruster_8"), -- Front-Left
    BL = peripheral.wrap("liquid_vector_thruster_9"), -- Back-Left
    FR = peripheral.wrap("liquid_vector_thruster_6"), -- Front-Right
    BR = peripheral.wrap("liquid_vector_thruster_7")  -- Back-Right
}

print("=== STARTING AUTOPILOT ===")
print("Gyroscope: " .. (gyro_name or "NOT FOUND!"))
print("Altimeter: " .. (alt_name or "NOT FOUND!"))

-- Базовый постоянный вектор вперёд
local forward_vector = 0.8
local current_steer = 0.0

local start_time = os.epoch("utc") / 1000

while true do
    local now = os.epoch("utc") / 1000
    local elapsed = now - start_time

    -- Первые 10 секунд летим строго прямо
    if elapsed < 10 then
        current_steer = 0.0
        print(string.format("[0-10s] FLYING STRAIGHT | Time: %.1fs", elapsed))
    else
        -- После 10 секунд начинаем плавно накренять векторы вправо
        if current_steer < 0.3 then
            current_steer = current_steer + 0.01 -- Скорость плавного разворота
        end
        print(string.format("[>10s] TURNING RIGHT | Steer: %.2f | Time: %.1fs", current_steer, elapsed))
    end

    -- Чтение датчиков для выравнивания (если они активны)
    local pitch_corr = 0
    local roll_corr = 0

    if gyro then
        -- Автоматический выбор методов получения углов
        local pitch = (gyro.getPitch and gyro.getPitch()) or 0
        local roll = (gyro.getRoll and gyro.getRoll()) or 0

        -- Простая компенсация наклона корпуса
        pitch_corr = -pitch * 0.02
        roll_corr = -roll * 0.02
    end

    -- Применяем векторы на моторы с учётом выравнивания и поворота
    -- Левая пара моторов (FL, BL)
    if thrusters.FL then thrusters.FL.setVector(current_steer + roll_corr, forward_vector + pitch_corr) end
    if thrusters.BL then thrusters.BL.setVector(current_steer + roll_corr, forward_vector + pitch_corr) end

    -- Правая пара моторов (FR, BR)
    if thrusters.FR then thrusters.FR.setVector(current_steer - roll_corr, forward_vector - pitch_corr) end
    if thrusters.BR then thrusters.BR.setVector(current_steer - roll_corr, forward_vector - pitch_corr) end

    sleep(0.1) -- Шаг цикла 100мс
end
