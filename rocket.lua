local thrusters = {
    ["Спереди-Слева (4)"]  = peripheral.wrap("liquid_vector_thruster_4"),[cite: 2]
    ["Сзади-Слева (5)"]   = peripheral.wrap("liquid_vector_thruster_5"),[cite: 2]
    ["Спереди-Справа (6)"] = peripheral.wrap("liquid_vector_thruster_6"),[cite: 2]
    ["Сзади-Справа (7)"]  = peripheral.wrap("liquid_vector_thruster_7") [cite: 2]
}

print("=== ТЕСТ ОРИЕНТАЦИИ ДВИГАТЕЛЕЙ ===")
print("Сбрасываем все векторы в 0...")

for name, t in pairs(thrusters) do
    if t then t.setVector(0, 0) end[cite: 3]
end

for name, t in pairs(thrusters) do
    if not t then
        print("ОШИБКА: " .. name .. " не найден!")
    else
        print("\nПроверяем: " .. name)
        
        -- 1. Сброс в 0
        t.setVector(0, 0)[cite: 3]
        print("  -> Вектор [0, 0]. Смотри: сопло смотрит СТРОГО ВНИЗ?")
        print("  (Нажми Enter для теста оси X)")
        read()

        -- 2. Тест оси X (+0.8)
        t.setVector(0.8, 0)[cite: 3]
        print("  -> Подали setVectorX(0.8). Сопло отклонилось ВПРАВО?")
        print("  (Нажми Enter для теста оси Y)")
        read()

        -- 3. Тест оси Y (+0.8)
        t.setVector(0, 0.8)[cite: 3]
        print("  -> Подали setVectorY(0.8). Сопло отклонилось ВПЕРЁД?")
        print("  (Нажми Enter, чтобы перейти к следующему)")
        read()

        -- Возвращаем в 0
        t.setVector(0, 0)[cite: 3]
    end
end

print("\nТест завершён! Все сопла возвращены в [0, 0].")
