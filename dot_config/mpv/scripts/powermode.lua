-- powermode.lua
-- 检测笔记本是否在用电池供电，结果写入 user-data/powermode/battery，
-- mpv.conf 里的 [battery] 档位会据此自动启用 / 恢复。
--
-- 快捷键（见 input.conf）：
--   Ctrl+b  script-binding powermode/cycle   自动 → 强制省电 → 强制性能 → 自动
--
-- 可选配置 script-opts/powermode.conf：
--   interval=20   电源状态的检测间隔（秒）

local utils = require "mp.utils"
local options = require "mp.options"

local o = { interval = 20 }
options.read_options(o, "powermode")

local SYS = "/sys/class/power_supply/"
local MODES = { "auto", "battery", "ac" }
local LABELS = { auto = "自动", battery = "强制省电", ac = "强制性能" }
local mode = "auto"

local function read_line(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local line = f:read("*l")
    f:close()
    return line
end

-- 有系统电池、且没有任何外接电源（适配器 / USB-C）在线，才算电池供电
local function on_battery()
    local has_battery, plugged = false, false
    for _, name in ipairs(utils.readdir(SYS) or {}) do
        local dir = SYS .. name .. "/"
        if read_line(dir .. "type") == "Battery" then
            -- 蓝牙鼠标、手柄等外设电池的 scope 是 Device，不算
            if read_line(dir .. "scope") ~= "Device" then
                has_battery = true
            end
        elseif read_line(dir .. "online") == "1" then
            plugged = true
        end
    end
    return has_battery and not plugged
end

local function update()
    local battery
    if mode == "auto" then
        battery = on_battery()
    else
        battery = mode == "battery"
    end
    if mp.get_property_native("user-data/powermode/battery") ~= battery then
        mp.set_property_native("user-data/powermode/battery", battery)
    end
    return battery
end

mp.add_key_binding(nil, "cycle", function()
    for i, m in ipairs(MODES) do
        if m == mode then
            mode = MODES[i % #MODES + 1]
            break
        end
    end
    local battery = update()
    local text = ("电源模式：%s（当前%s）"):format(LABELS[mode], battery and "省电" or "高画质")
    -- 有 mochi 时用它的圆角气泡，否则用内置提示
    if mp.get_property_native("user-data/mochi/loaded") then
        mp.commandv("script-message-to", "mochi", "toast", text, "bolt")
    else
        mp.osd_message(text)
    end
end)

update()
mp.add_periodic_timer(o.interval, function()
    if mode == "auto" then update() end
end)
