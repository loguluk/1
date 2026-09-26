-- Прямое подключение датчиков по сторонам компьютера и сетевых двигателей
local gyro = peripheral.wrap("back") or peripheral.wrap("gimbal_sensor")
local altimeter = peripheral.wrap("front") or peripheral.wrap("altitude_sensor")

local thrusters = {
    FL = peripheral.wrap("liquid_vector_thruster_8"), -- Front-Left
    BL = peripheral.wrap("liquid_vector_thruster_9"), -- Back-Left
    FR = peripheral.wrap("liquid_vector_thruster_6"), -- Front-Right
    BR = peripheral.wrap("liquid_vector_thruster_7")  -- Back-Right
}

print("=== STARTING AUTOPILOT ===")
print("Gyroscope (back): " .. (gyro and "OK" or "NOT FOUND!"))
print("Altimeter (front): " .. (altimeter and "OK" or "NOT FOUND!"))

-- 1. Включение моторов и запуск тяги
print("Enabling thrust on all engines...")
for name, t in pairs(thrusters) do
    if t then
        if t.setThrust then t.setThrust(1.0) end
        if t.setPower then t.setPower(1.0) end
        if t.setThrottle then t.setThrottle(1.0) end
        if t.setEnabled then t.setEnabled(true) end
        print("Engine " .. name .. " ENABLED.")
    else
        print("WARNING: Engine " .. name .. " NOT CONNECTED!")
    end
end

-- Параметры автопилота
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
        -- После 10 секунд начинаем плавно повертать вправо
        if current_steer < 0.3 then
            current_steer = current_steer + 0.01 -- Плавность разворота
        end
        print(string.format("[>10s] TURNING RIGHT | Steer: %.2f | Time: %.1fs", current_steer, elapsed))
    end

    -- Чтение гироскопа для компенсации наклона
    local pitch_corr = 0
    local roll_corr = 0

    if gyro then
        local pitch = (gyro.getPitch and gyro.getPitch()) or 0
        local roll = (gyro.getRoll and gyro.getRoll()) or 0

        -- Автоматическое выравнивание
        pitch_corr = -pitch * 0.02
        roll_corr = -roll * 0.02
    end

    -- Управление векторами сопел
    if thrusters.FL then thrusters.FL.setVector(current_steer + roll_corr, forward_vector + pitch_corr) end
    if thrusters.BL then thrusters.BL.setVector(current_steer + roll_corr, forward_vector + pitch_corr) end
    if thrusters.FR then thrusters.FR.setVector(current_steer - roll_corr, forward_vector - pitch_corr) end
    if thrusters.BR then thrusters.BR.setVector(current_steer - roll_corr, forward_vector - pitch_corr) end

    sleep(0.1)
end
