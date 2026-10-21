-- mochi.lua
-- 圆润风格的 mpv 界面：悬浮圆角控制栏、胶囊提示气泡、暂停动画、空闲页。
-- 用来替代内置 OSC（mpv.conf 里设置了 osc=no、osd-on-seek=no）。
--
-- 可选配置 script-opts/mochi.conf，选项见下方 o 表。
-- 按键（input.conf）：
--   DEL  script-binding mochi/cycle-visibility    控制栏：自动隐藏 / 常驻 / 隐藏
-- 其他脚本或按键可以弹出提示气泡：
--   script-message-to mochi toast <文字> [图标名]

local assdraw = require "mp.assdraw"
local options = require "mp.options"

local o = {
    visibility = "auto",        -- auto：鼠标移到底部时出现 / always：常驻 / never：不显示
    trigger_height = 200,       -- auto 时，鼠标进入窗口底部这么高的区域才弹出（以 1080p 为基准）；0 = 任意位置移动都弹出
    hide_timeout = 1.2,         -- 鼠标停下多少秒后隐藏控制栏（停在控制栏上时不隐藏）
    fade_time = 0.15,
    scale = 1,
    max_width = 1360,           -- 控制栏最大宽度（以 1080p 窗口为基准）
    font = "Noto Sans CJK SC",
    icon_font = "Material Symbols Rounded",
    accent = "#FFB787",
    foreground = "#F2E8E2",
    background = "#1A120D",
    opacity = 0.85,             -- 面板不透明度
    toast_duration = 1.2,
    pause_flash = true,         -- 暂停 / 继续时画面中央的圆形动画
    avoid_subtitles = true,     -- 控制栏出现时把字幕往上挪
}

---------------------------------------------------------------------------
-- 工具
---------------------------------------------------------------------------

-- mpv 内置的是 Lua 5.1，没有 \u{} 转义
local function utf8char(cp)
    if cp < 0x80 then return string.char(cp) end
    if cp < 0x800 then
        return string.char(0xC0 + math.floor(cp / 0x40), 0x80 + cp % 0x40)
    end
    return string.char(0xE0 + math.floor(cp / 0x1000),
                       0x80 + math.floor(cp / 0x40) % 0x40, 0x80 + cp % 0x40)
end

-- Material Symbols 的码位
local ICONS = {}
for name, cp in pairs({
    play = 0xe037, pause = 0xe034, prev = 0xe045, next = 0xe044,
    volume_up = 0xe050, volume_down = 0xe04d, volume_mute = 0xe04e, volume_off = 0xe04f,
    subtitles = 0xe048, subtitles_off = 0xef72, audio = 0xe405,
    fullscreen = 0xe5d0, fullscreen_exit = 0xe5d1, menu = 0xe5d2,
    forward = 0xe01f, rewind = 0xe020, speed = 0xe9e4, movie = 0xe02c,
    play_circle = 0xe1c4, info = 0xe88e, night = 0xef44, rotate = 0xe41a,
    bolt = 0xea0b, memory = 0xe322, timer = 0xe425, link = 0xe157,
}) do ICONS[name] = utf8char(cp) end

local C = {}
local function hex_to_ass(hex)
    hex = hex:gsub("#", "")
    return hex:sub(5, 6) .. hex:sub(3, 4) .. hex:sub(1, 2)
end
local function update_colors()
    C.accent = hex_to_ass(o.accent)
    C.fg = hex_to_ass(o.foreground)
    C.bg = hex_to_ass(o.background)
    C.black = "000000"
end

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

local function alpha(opacity)
    return string.format("%02X", math.floor((1 - clamp(opacity, 0, 1)) * 255 + 0.5))
end

local function escape(s)
    return mp.command_native({"escape-ass", tostring(s)}) or ""
end

-- 估算文字宽度。ASS 的 \fs 是行高，Noto Sans CJK 的字身约为它的 0.69
local function char_width(ch, size)
    local b = ch:byte()
    if b == 0x20 then return size * 0.18 end
    if b < 0x80 then return size * 0.38 end
    if b < 0xE0 then return size * 0.5 end
    return size * 0.69
end

local function text_width(s, size)
    local w = 0
    for ch in s:gmatch("[%z\1-\127\194-\244][\128-\191]*") do w = w + char_width(ch, size) end
    return w
end

local function truncate(s, size, max_w)
    if text_width(s, size) <= max_w then return s end
    local out, w = {}, size
    for ch in s:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
        w = w + char_width(ch, size)
        if w > max_w then break end
        out[#out + 1] = ch
    end
    return table.concat(out) .. "…"
end

local function fmt_time(t, hours)
    if not t then return "--:--" end
    t = math.floor(math.max(0, t))
    local h, m, s = math.floor(t / 3600), math.floor(t / 60) % 60, t % 60
    if h > 0 or hours then return string.format("%d:%02d:%02d", h, m, s) end
    return string.format("%02d:%02d", m, s)
end

local function track_label(t)
    if not t then return "关闭" end
    local title = t.title ~= "" and t.title or nil
    local lang = t.lang ~= "" and t.lang or nil
    if title and lang then return title .. " [" .. lang .. "]" end
    return title or lang or ("轨道 " .. t.id)
end

---------------------------------------------------------------------------
-- 状态
---------------------------------------------------------------------------

local p = {}                     -- 属性缓存
local st = {
    W = 0, H = 0, s = 1,
    mx = -1, my = -1, hover = false, last_move = -10,
    alpha = 0, target = 0, last_render = 0,
    hits = {}, panel = nil,
    loaded_at = -10, pos = nil, pos_prev = nil,
    show_remaining = false,
    own_margins = {},
}
local ov = mp.create_osd_overlay("ass-events")
local A                          -- 当前帧的 assdraw 对象

---------------------------------------------------------------------------
-- 绘制原语
---------------------------------------------------------------------------

-- 每个事件都带 \4a&HFF&：mpv.conf 里 osd-border-style=background-box 会给所有 OSD 文字
-- 套底框，这里把底框设成全透明
local function rrect(x0, y0, x1, y1, r, color, opacity, extra)
    if opacity <= 0 or x1 <= x0 or y1 <= y0 then return end
    A:new_event()
    A:append(string.format("{\\an7\\pos(0,0)\\bord0\\shad0\\4a&HFF&\\1c&H%s&\\1a&H%s&%s}",
                           color, alpha(opacity), extra or "\\blur0"))
    A:draw_start()
    A:round_rect_cw(x0, y0, x1, y1, math.min(r, (x1 - x0) / 2, (y1 - y0) / 2))
    A:draw_stop()
end

local function circle(cx, cy, r, color, opacity, extra)
    rrect(cx - r, cy - r, cx + r, cy + r, r, color, opacity, extra)
end

-- 柔和的投影，让浮层有“浮起来”的感觉
local function shadow(x0, y0, x1, y1, r, opacity)
    local s = st.s
    rrect(x0, y0 + 4 * s, x1, y1 + 4 * s, r, C.black, 0.45 * opacity,
          string.format("\\blur%.1f", 14 * s))
end

local function text(x, y, an, str, size, color, opacity, font, extra)
    if opacity <= 0 then return end
    A:new_event()
    A:append(string.format("{\\an%d\\pos(%.1f,%.1f)\\fn%s\\fs%.1f\\bord0\\shad0\\4a&HFF&\\blur0\\q2\\1c&H%s&\\1a&H%s&%s}",
                           an, x, y, font or o.font, size, color, alpha(opacity), extra or ""))
    A:append(str)
end

local function icon(x, y, name, size, color, opacity)
    text(x, y, 5, ICONS[name] or "", size, color, opacity, o.icon_font)
end

-- 实心圆角的播放 / 暂停图形（字体图标是空心的，这里自己画）
-- 圆角靠同色描边实现：libass 的描边拐角是圆的
local function play_pause(cx, cy, size, paused, color, opacity)
    if opacity <= 0 then return end
    local r = size * 0.1
    A:new_event()
    A:append(string.format("{\\an7\\pos(0,0)\\bord%.2f\\shad0\\4a&HFF&\\blur0\\1c&H%s&\\3c&H%s&\\1a&H%s&\\3a&H%s&}",
                           r, color, color, alpha(opacity), alpha(opacity)))
    A:draw_start()
    if paused then
        -- 三角形重心偏左，往右挪一点看起来才居中
        local h, w = size - 2 * r, size * 0.88 - 2 * r
        local x0 = cx - w * 0.42
        A:move_to(x0, cy - h / 2)
        A:line_to(x0 + w, cy)
        A:line_to(x0, cy + h / 2)
    else
        local h, bw, gap = size * 0.86 - 2 * r, size * 0.3 - 2 * r, size * 0.26 + 2 * r
        for _, x0 in ipairs({ cx - gap / 2 - bw, cx + gap / 2 }) do
            A:move_to(x0, cy - h / 2)
            A:line_to(x0 + bw, cy - h / 2)
            A:line_to(x0 + bw, cy + h / 2)
            A:line_to(x0, cy + h / 2)
        end
    end
    A:draw_stop()
end

-- 胶囊形小气泡（进度条悬停时间、按钮说明）
local function bubble(cx, y_bottom, str, opacity)
    local s = st.s
    local size = 17 * s
    local w = text_width(str, size) + 24 * s
    local h = 32 * s
    local x0 = clamp(cx - w / 2, 8 * s, st.W - w - 8 * s)
    local y0 = y_bottom - h
    shadow(x0, y0, x0 + w, y0 + h, h / 2, opacity * 0.6)
    rrect(x0, y0, x0 + w, y0 + h, h / 2, C.bg, 0.95 * opacity)
    text(x0 + w / 2, y0 + h / 2, 5, escape(str), size, C.fg, opacity)
end

local function hit(id, x0, y0, x1, y1, t)
    t.id, t.x0, t.y0, t.x1, t.y1 = id, x0, y0, x1, y1
    st.hits[#st.hits + 1] = t
    return t
end

local function hit_at(x, y, list)
    list = list or st.hits
    for i = #list, 1, -1 do
        local h = list[i]
        if x >= h.x0 and x <= h.x1 and y >= h.y0 and y <= h.y1 then return h end
    end
end

-- 当前帧的点击区域还在构建中，悬停判断用上一帧的
local function hovered(id)
    if st.dragging then return st.dragging.id == id end
    local h = st.hover and hit_at(st.mx, st.my, st.prev_hits or {})
    return h and h.id == id
end

local function inside(r, x, y)
    return r and x >= r[1] and x <= r[3] and y >= r[2] and y <= r[4]
end

---------------------------------------------------------------------------
-- 提示气泡 / 暂停动画
---------------------------------------------------------------------------

local request_render

local function toast(str, icon_name, bar, duration)
    local now = mp.get_time()
    local old = st.toast
    st.toast = {
        text = str, icon = icon_name, bar = bar,
        -- 已经在显示时直接替换内容，不重新淡入
        t0 = (old and now < old.t1) and old.t0 or now,
        t1 = now + (duration or o.toast_duration),
    }
    request_render()
end

-- 刚打开文件、或者鼠标正在操作控制栏时，不弹自动提示
local function quiet()
    return mp.get_time() - st.loaded_at < 1 or st.dragging
        or (st.hover and inside(st.panel, st.mx, st.my) and st.target > 0)
end

local function draw_toast(now)
    local t = st.toast
    if not t then return false end
    if now > t.t1 + o.fade_time then st.toast = nil return false end
    local a = math.min(1, (now - t.t0) / o.fade_time, (t.t1 + o.fade_time - now) / o.fade_time)
    local s = st.s
    local size = 21 * s
    local h = 52 * s
    local pad = 22 * s
    local iw = t.icon and 38 * s or 0
    local label = truncate(t.text, size, st.W * 0.6)
    local tw = text_width(label, size)
    local bw = t.bar and 120 * s or 0
    local w = pad + iw + tw + (t.bar and (16 * s + bw) or 0) + pad
    local x0 = (st.W - w) / 2
    local y0 = 30 * s + (1 - a) * -8 * s   -- 淡入时从上方轻轻落下
    local cy = y0 + h / 2
    shadow(x0, y0, x0 + w, y0 + h, h / 2, a)
    rrect(x0, y0, x0 + w, y0 + h, h / 2, C.bg, o.opacity * a)
    local x = x0 + pad
    if t.icon then
        icon(x + 13 * s, cy, t.icon, 32 * s, C.accent, a)
        x = x + iw
    end
    text(x, cy, 4, escape(label), size, C.fg, a)
    if t.bar then
        local bx0 = x + tw + 16 * s
        local th = 6 * s
        rrect(bx0, cy - th / 2, bx0 + bw, cy + th / 2, th / 2, C.fg, 0.2 * a)
        rrect(bx0, cy - th / 2, bx0 + bw * clamp(t.bar, 0, 1), cy + th / 2, th / 2, C.accent, a)
    end
    return a < 1
end

local function draw_flash(now)
    local f = st.flash
    if not f then return false end
    local k = (now - f.t0) / 0.55
    if k >= 1 then st.flash = nil return false end
    local s = st.s
    local ease = 1 - (1 - k) * (1 - k)
    local a = 1 - ease
    local r = (44 + 14 * ease) * s
    local cx, cy = st.W / 2, st.H / 2
    circle(cx, cy, r, C.bg, 0.7 * a)
    play_pause(cx, cy, r * 0.75, f.icon == "play", C.fg, a)
    return true
end

---------------------------------------------------------------------------
-- 空闲页
---------------------------------------------------------------------------

local function draw_idle()
    local s = st.s
    local w, h = 440 * s, 220 * s
    local x0, y0 = (st.W - w) / 2, (st.H - h) / 2
    shadow(x0, y0, x0 + w, y0 + h, 32 * s, 1)
    rrect(x0, y0, x0 + w, y0 + h, 32 * s, C.bg, o.opacity)
    circle(st.W / 2, y0 + 70 * s, 38 * s, C.accent, 0.16)
    icon(st.W / 2, y0 + 70 * s, "play_circle", 50 * s, C.accent, 1)
    text(st.W / 2, y0 + 140 * s, 5, "把视频拖进来开始播放", 24 * s, C.fg, 1)
    text(st.W / 2, y0 + 178 * s, 5, "Ctrl+V 粘贴链接　·　中键打开菜单", 16 * s, C.fg, 0.55)
end

---------------------------------------------------------------------------
-- 控制栏
---------------------------------------------------------------------------

local function cmd(str) return function() mp.command(str) end end

-- 圆形图标按钮：悬停时出现浅色圆底
local function button(id, cx, cy, name, a, opts)
    local s = st.s
    opts = opts or {}
    local r = 21 * s
    local enabled = opts.enabled ~= false
    if enabled and hovered(id) then circle(cx, cy, r, C.fg, 0.14 * a) end
    icon(cx, cy, name, 31 * s, opts.color or C.fg, (enabled and 1 or 0.35) * a)
    if enabled then
        hit(id, cx - r, cy - r, cx + r, cy + r, opts)
        if opts.tip and hovered(id) then
            st.tip = { x = cx, text = opts.tip }
        end
    end
end

local function draw_seekbar(x0, x1, cy, a)
    local s = st.s
    local dur = p.duration
    local pos = mp.get_property_number("time-pos")
    local over = hovered("seek")
    local th = (over and 9 or 6) * s
    local w = x1 - x0
    local frac = (dur and dur > 0 and pos) and clamp(pos / dur, 0, 1) or 0
    if st.dragging and st.dragging.id == "seek" and st.drag_frac then frac = st.drag_frac end

    -- 底槽、已缓存、已播放
    rrect(x0, cy - th / 2, x1, cy + th / 2, th / 2, C.fg, 0.18 * a)
    if dur and dur > 0 then
        local cache = mp.get_property_native("demuxer-cache-state")
        for _, r in ipairs(cache and cache["seekable-ranges"] or {}) do
            local rx0 = x0 + w * clamp(r.start / dur, 0, 1)
            local rx1 = x0 + w * clamp(r["end"] / dur, 0, 1)
            rrect(rx0, cy - th / 2, rx1, cy + th / 2, th / 2, C.fg, 0.16 * a)
        end
    end
    rrect(x0, cy - th / 2, x0 + w * frac, cy + th / 2, th / 2, C.accent, a)

    -- 章节：在进度条上留一道小缺口
    local chapters = p["chapter-list"] or {}
    if dur and dur > 0 then
        for _, c in ipairs(chapters) do
            if c.time > 0 and c.time < dur then
                local cx = x0 + w * c.time / dur
                rrect(cx - 1.5 * s, cy - th / 2 - 1, cx + 1.5 * s, cy + th / 2 + 1, 1.5 * s, C.bg, a)
            end
        end
    end

    -- 圆形拖柄
    local kr = (over and 9 or 7) * s
    local kx = x0 + w * frac
    circle(kx, cy, kr + 2 * s, C.bg, 0.5 * a)
    circle(kx, cy, kr, C.fg, a)

    if dur and dur > 0 then
        hit("seek", x0 - 6 * s, cy - 18 * s, x1 + 6 * s, cy + 18 * s, {
            drag = function(x, final)
                local f = clamp((x - x0) / w, 0, 1)
                st.drag_frac = f
                mp.commandv("seek", tostring(f * 100),
                            final and "absolute-percent+exact" or "absolute-percent+keyframes")
                if final then st.drag_frac = nil end
            end,
            wheel = function(dir) mp.commandv("seek", tostring(5 * dir)) end,
        })
        if over then
            local mx = st.dragging and (x0 + w * frac) or clamp(st.mx, x0, x1)
            local t = (mx - x0) / w * dur
            local label = fmt_time(t, dur >= 3600)
            for i = #chapters, 1, -1 do
                if chapters[i].time <= t then
                    if chapters[i].title and chapters[i].title ~= "" then
                        label = label .. "  " .. chapters[i].title
                    end
                    break
                end
            end
            bubble(mx, cy - 16 * s, label, a)
        end
    end
end

local function draw_volume(x0, cy, a)
    local s = st.s
    local w = 84 * s
    local th = (hovered("volume") and 8 or 6) * s
    local vol = p.volume or 100
    local f = clamp(vol / 100, 0, 1)
    local dim = p.mute and 0.4 or 1
    rrect(x0, cy - th / 2, x0 + w, cy + th / 2, th / 2, C.fg, 0.18 * a)
    rrect(x0, cy - th / 2, x0 + w * f, cy + th / 2, th / 2, C.accent, a * dim)
    if hovered("volume") then circle(x0 + w * f, cy, 7 * s, C.fg, a) end
    hit("volume", x0 - 6 * s, cy - 16 * s, x0 + w + 6 * s, cy + 16 * s, {
        drag = function(x)
            mp.commandv("no-osd", "set", "volume", tostring(math.floor(clamp((x - x0) / w, 0, 1) * 100 + 0.5)))
        end,
        wheel = function(dir) mp.commandv("no-osd", "add", "volume", tostring(5 * dir)) end,
    })
    if hovered("volume") then
        st.tip = { x = x0 + w / 2, text = string.format("音量 %d%%", math.floor(vol + 0.5)) }
    end
    return w
end

local function draw_panel(a)
    local s = st.s
    local r = st.panel
    local x0, y0, x1, y1 = r[1], r[2], r[3], r[4]
    local radius = 24 * s
    shadow(x0, y0, x1, y1, radius, a)
    rrect(x0, y0, x1, y1, radius, C.bg, o.opacity * a)
    hit("panel", x0, y0, x1, y1, {})

    local pad = 24 * s
    st.tip = nil
    draw_seekbar(x0 + pad, x1 - pad, y0 + 24 * s, a)

    local cy = y1 - 34 * s
    local count = p["playlist-count"] or 0
    local ppos = p["playlist-pos"] or 0

    -- 左侧：上一个 / 播放暂停 / 下一个
    local x = x0 + pad + 14 * s
    button("prev", x, cy, "prev", a, {
        enabled = count > 1 and ppos > 0, click = cmd("playlist-prev"),
        rclick = cmd("script-binding select/select-playlist"), tip = "上一个",
    })
    x = x + 48 * s
    local pr = (hovered("play") and 25 or 23) * s
    circle(x, cy, pr, C.accent, a)
    play_pause(x, cy, 18 * s, p.pause, C.bg, a)
    hit("play", x - pr, cy - pr, x + pr, cy + pr, { click = cmd("cycle pause") })
    x = x + 48 * s
    button("next", x, cy, "next", a, {
        enabled = count > 1 and ppos < count - 1, click = cmd("playlist-next"),
        rclick = cmd("script-binding select/select-playlist"), tip = "下一个",
    })

    -- 时间：点击切换 已播放/总长 与 剩余时间
    local dur = p.duration
    local pos = mp.get_property_number("time-pos")
    local hours = dur and dur >= 3600
    local cur = fmt_time(pos, hours)
    local tail
    if st.show_remaining and dur and pos then
        tail = " / -" .. fmt_time(dur - pos, hours)
    else
        tail = " / " .. fmt_time(dur, hours)
    end
    local tsize = 20 * s
    local tx = x + 32 * s
    text(tx, cy, 4, cur .. "{\\1a&H" .. alpha(0.55 * a) .. "&}" .. tail, tsize, C.fg, a, nil, "\\b1")
    local tw = text_width(cur .. tail, tsize) * 1.04
    hit("time", tx, cy - 16 * s, tx + tw, cy + 16 * s, {
        click = function() st.show_remaining = not st.show_remaining; request_render() end,
    })

    -- 右侧，从右往左排
    local rx = x1 - pad - 14 * s
    button("fullscreen", rx, cy, p.fullscreen and "fullscreen_exit" or "fullscreen", a, {
        click = cmd("cycle fullscreen"), tip = p.fullscreen and "退出全屏" or "全屏",
    })
    rx = rx - 44 * s
    button("menu", rx, cy, "menu", a, {
        click = cmd("script-binding select/menu"), tip = "菜单",
    })
    rx = rx - 34 * s
    local narrow = (x1 - x0) < 760 * s
    if not narrow then
        rx = rx - draw_volume(rx - 84 * s, cy, a) - 22 * s
    else
        rx = rx - 10 * s
    end
    local vol_icon = (p.mute and "volume_off") or ((p.volume or 100) < 50 and "volume_down") or "volume_up"
    button("mute", rx, cy, vol_icon, a, {
        click = cmd("no-osd cycle mute"),
        wheel = function(dir) mp.commandv("no-osd", "add", "volume", tostring(5 * dir)) end,
        tip = p.mute and "取消静音" or "静音",
    })
    rx = rx - 46 * s
    local tracks = p["track-list"] or {}
    local nsub, naudio = 0, 0
    for _, t in ipairs(tracks) do
        if t.type == "sub" then nsub = nsub + 1 elseif t.type == "audio" then naudio = naudio + 1 end
    end
    button("audio", rx, cy, "audio", a, {
        enabled = naudio > 0, click = cmd("cycle audio"),
        rclick = cmd("script-binding select/select-aid"),
        tip = "音轨：" .. track_label(p["current-tracks/audio"]) .. (naudio > 1 and "（右键选择）" or ""),
    })
    rx = rx - 44 * s
    local sub = p["current-tracks/sub"]
    button("sub", rx, cy, sub and "subtitles" or "subtitles_off", a, {
        enabled = nsub > 0, click = cmd("cycle sub"),
        rclick = cmd("script-binding select/select-sid"),
        tip = "字幕：" .. track_label(sub) .. (nsub > 1 and "（右键选择）" or ""),
    })
    rx = rx - 26 * s

    -- 倍速不是 1 时显示一个胶囊，点击恢复
    local speed = p.speed or 1
    if math.abs(speed - 1) > 0.001 then
        local label = string.format("%.2f", speed):gsub("0+$", ""):gsub("%.$", "") .. "×"
        local size = 16 * s
        local w = text_width(label, size) + 22 * s
        local h = 28 * s
        local sx0 = rx - w
        rrect(sx0, cy - h / 2, rx, cy + h / 2, h / 2, C.accent, (hovered("speed") and 0.32 or 0.2) * a)
        text(sx0 + w / 2, cy, 5, label, size, C.accent, a, nil, "\\b1")
        hit("speed", sx0, cy - h / 2, rx, cy + h / 2, { click = cmd("no-osd set speed 1"), tip = "恢复 1 倍速" })
        if hovered("speed") then st.tip = { x = sx0 + w / 2, text = "恢复 1 倍速" } end
        rx = sx0 - 14 * s
    end

    -- 中间：标题（播放列表里有多个文件时带序号）
    local title_x = tx + tw + 22 * s
    local max_w = rx - title_x - 8 * s
    local title = p["media-title"] or ""
    if count > 1 then title = string.format("%d/%d · %s", ppos + 1, count, title) end
    local size = 18 * s
    if max_w > 60 * s and title ~= "" then
        local shown = truncate(title, size, max_w)
        text(title_x, cy, 4, escape(shown), size, C.fg, 0.7 * a)
        hit("title", title_x, cy - 16 * s, title_x + text_width(shown, size), cy + 16 * s, {
            click = cmd("script-binding select/select-playlist"),
            rclick = cmd("script-binding select/select-watch-history"),
        })
        if shown ~= title and hovered("title") then
            st.tip = { x = clamp(st.mx, x0 + 200 * s, x1 - 200 * s), text = title }
        end
    end

    if st.tip then bubble(st.tip.x, y0 - 10 * s, st.tip.text, a) end
end

---------------------------------------------------------------------------
-- 字幕避让：控制栏出现时临时抬高 sub-margin-y
---------------------------------------------------------------------------

local function update_sub_margin()
    if not o.avoid_subtitles or not st.base_margin then return end
    local want = st.base_margin
    if st.target > 0 and st.panel then
        local dims = p["osd-dimensions"] or {}
        local ref = st.H
        if not mp.get_property_bool("sub-scale-with-window") then
            ref = st.H - (dims.mt or 0) - (dims.mb or 0)
        end
        if ref > 0 then
            local lift = (st.H - st.panel[2] + 6 * st.s) * 720 / ref
            want = math.max(want, math.floor(lift + 0.5))
        end
    end
    if want ~= st.applied_margin then
        st.applied_margin = want
        st.own_margins[want] = true
        mp.set_property_number("sub-margin-y", want)
    end
end

---------------------------------------------------------------------------
-- 输入
---------------------------------------------------------------------------

local function on_left_down()
    local h = hit_at(st.mx, st.my)
    st.pressed = h and h.id
    if h and h.drag then
        st.dragging = h
        h.drag(st.mx, false)
    end
    request_render()
end

local function on_left_up()
    if st.dragging then
        local d = st.dragging
        st.dragging = nil
        d.drag(st.mx, true)
    else
        local h = hit_at(st.mx, st.my)
        if h and h.id == st.pressed and h.click then h.click() end
    end
    st.pressed = nil
    request_render()
end

local function on_right_up()
    local h = hit_at(st.mx, st.my)
    if h and h.rclick then h.rclick() end
end

local function on_wheel(dir)
    local h = hit_at(st.mx, st.my)
    if h and h.wheel then h.wheel(dir)
    else mp.commandv("no-osd", "add", "volume", tostring(2 * dir)) end
    request_render()
end

-- 有的输入源（触控板轻点、mouse 命令）会发出合并的“按下+抬起”事件
local function on_left_press()
    on_left_down()
    on_left_up()
end

-- {按键, 合并事件回调, 按下回调, 抬起回调}
mp.set_key_bindings({
    {"mbtn_left", on_left_press, on_left_down, on_left_up},
    {"mbtn_right", on_right_up, nil, on_right_up},
    {"wheel_up", function() on_wheel(1) end},
    {"wheel_down", function() on_wheel(-1) end},
    {"mbtn_left_dbl", "ignore"},
    {"mbtn_right_dbl", "ignore"},
    {"mbtn_mid", "ignore"},
}, "mochi_input", "force")

local function update_input()
    local r = st.panel
    if st.alpha > 0.05 and r and not p["idle-active"] then
        if st.dragging then
            mp.set_mouse_area(0, 0, st.W, st.H, "mochi_input")
        else
            -- 往上多留一点，让悬停气泡区域也不会点穿
            mp.set_mouse_area(r[1], r[2] - 4 * st.s, r[3], r[4], "mochi_input")
        end
        if not st.input_on then
            mp.enable_key_bindings("mochi_input")
            st.input_on = true
        end
    elseif st.input_on then
        mp.disable_key_bindings("mochi_input")
        st.input_on = false
    end
end

---------------------------------------------------------------------------
-- 渲染循环
---------------------------------------------------------------------------

local function schedule(delay)
    local at = mp.get_time() + delay
    if st.timer then
        if st.timer_at <= at then return end
        st.timer:kill()
    end
    st.timer_at = at
    st.timer = mp.add_timeout(delay, function()
        st.timer = nil
        st.render()
    end)
end

request_render = function()
    schedule(math.max(0, st.last_render + 1 / 60 - mp.get_time()))
end

-- 窗口底部的触发区：鼠标在这里移动才弹出控制栏，离开就收起
local function in_trigger_zone()
    return o.trigger_height <= 0 or st.my >= st.H - o.trigger_height * st.s
end

local function panel_target(now)
    if p["idle-active"] or o.visibility == "never" then return 0 end
    if o.visibility == "always" or st.dragging then return 1 end
    if not st.hover then return 0 end
    if inside(st.panel, st.mx, st.my) then return 1 end
    if in_trigger_zone() and now - st.last_move < o.hide_timeout then return 1 end
    return 0
end

function st.render()
    local now = mp.get_time()
    local dt = math.min(0.1, now - st.last_render)
    st.last_render = now
    local dims = p["osd-dimensions"] or {}
    st.W, st.H = dims.w or 0, dims.h or 0
    if st.W <= 0 or st.H <= 0 then return end

    st.s = clamp(math.min(st.H / 1080, st.W / 1500), 0.55, 2.5) * o.scale
    local s = st.s
    local pw = math.min(st.W - 48 * s, o.max_width * s)
    local y1 = st.H - 20 * s
    st.panel = { (st.W - pw) / 2, y1 - 104 * s, (st.W + pw) / 2, y1 }

    st.target = panel_target(now)
    local step = o.fade_time > 0 and dt / o.fade_time or 1
    if st.alpha < st.target then st.alpha = math.min(st.target, st.alpha + step)
    elseif st.alpha > st.target then st.alpha = math.max(st.target, st.alpha - step) end

    A = assdraw.ass_new()
    st.prev_hits = st.hits
    st.hits = {}
    if p["idle-active"] then draw_idle() end
    local busy = draw_flash(now)
    if st.alpha > 0 and not p["idle-active"] then draw_panel(st.alpha) end
    busy = draw_toast(now) or busy

    ov.res_x, ov.res_y = st.W, st.H
    ov.data = A.text
    ov:update()
    update_input()
    update_sub_margin()

    if busy or st.alpha ~= st.target or st.dragging then
        schedule(1 / 60)
    elseif st.alpha > 0 or st.toast then
        schedule(0.1)     -- 刷新时间和进度
    end
end

---------------------------------------------------------------------------
-- 属性与事件
---------------------------------------------------------------------------

local function observe(name, kind, cb)
    mp.observe_property(name, kind, function(_, v)
        local old = p[name]
        p[name] = v
        if cb then cb(v, old) end
        request_render()
    end)
end

for _, name in ipairs({"duration", "chapter-list", "playlist-count", "playlist-pos",
                       "media-title", "fullscreen", "idle-active", "track-list", "osd-dimensions"}) do
    observe(name, "native")
end

observe("pause", "bool", function(v, old)
    if o.pause_flash and old ~= nil and v ~= old and not quiet()
       and not mp.get_property_bool("eof-reached") then
        st.flash = { icon = v and "pause" or "play", t0 = mp.get_time() }
    end
end)

observe("volume", "number", function(v, old)
    if old and v ~= old and not quiet() then
        toast(string.format("音量 %d%%", math.floor(v + 0.5)), v < 50 and "volume_down" or "volume_up", v / 100)
    end
end)

observe("mute", "bool", function(v, old)
    if old ~= nil and v ~= old and not quiet() then
        toast(v and "静音" or string.format("音量 %d%%", math.floor((p.volume or 100) + 0.5)),
              v and "volume_off" or "volume_up", (not v) and (p.volume or 100) / 100 or nil)
    end
end)

observe("speed", "number", function(v, old)
    if old and v ~= old and not quiet() then
        toast(string.format("倍速 %.2f×", v):gsub("0+×", "×"):gsub("%.×", "×"), "speed")
    end
end)

local function delay_toast(label)
    return function(v, old)
        if old and v ~= old and not quiet() then
            toast(string.format("%s %+d ms", label, math.floor(v * 1000 + (v >= 0 and 0.5 or -0.5))), "timer")
        end
    end
end
observe("sub-delay", "number", delay_toast("字幕延迟"))
observe("audio-delay", "number", delay_toast("音频延迟"))

local function track_toast(prefix, icon_on, icon_off)
    return function(v, old)
        local id, old_id = v and v.id, old and old.id
        if id ~= old_id and not quiet() then
            toast(prefix .. track_label(v), v and icon_on or icon_off)
        end
    end
end
observe("current-tracks/sub", "native", track_toast("字幕：", "subtitles", "subtitles_off"))
observe("current-tracks/audio", "native", track_toast("音轨：", "audio", "audio"))

mp.observe_property("time-pos", "number", function(_, v)
    if v and st.pos and math.abs(v - st.pos) > 0.001 then st.pos_prev = st.pos end
    st.pos = v
end)

-- 跳转提示：显示目标时间、进度和所在章节
mp.register_event("seek", function()
    if quiet() then return end
    local t = mp.get_property_number("time-pos")
    local dur = p.duration
    if not t then return end
    -- 循环播放回到开头时不提示
    local a, b = mp.get_property_native("ab-loop-a"), mp.get_property_native("ab-loop-b")
    if type(a) == "number" and type(b) == "number" and math.abs(t - a) < 0.5 then return end
    if mp.get_property("loop-file") ~= "no" and t < 0.5 then return end

    local ref = st.pos
    if ref and math.abs(ref - t) < 0.01 then ref = st.pos_prev end
    local forward = not ref or t >= ref
    local hours = dur and dur >= 3600
    local label = fmt_time(t, hours) .. (dur and (" / " .. fmt_time(dur, hours)) or "")
    local ch = mp.get_property_native("chapter")
    local chapters = p["chapter-list"] or {}
    if ch and ch >= 0 and chapters[ch + 1] and (chapters[ch + 1].title or "") ~= "" then
        label = label .. " · " .. chapters[ch + 1].title
    end
    toast(label, forward and "forward" or "rewind", dur and dur > 0 and t / dur or nil)
end)

mp.register_event("start-file", function()
    st.loaded_at = mp.get_time() + 30   -- 加载期间保持安静，file-loaded 时再重新计时
end)

mp.register_event("file-loaded", function()
    st.loaded_at = mp.get_time()
    st.toast = nil
    local title = mp.get_property("media-title") or ""
    local v = mp.get_property_native("current-tracks/video")
    local music = not v or v.albumart
    if title ~= "" then toast(title, music and "audio" or "movie", nil, 2) end
end)

mp.observe_property("mouse-pos", "native", function(_, m)
    if not m then return end
    if m.x ~= st.mx or m.y ~= st.my then
        if m.hover then st.last_move = mp.get_time() end
        st.mx, st.my = m.x, m.y
        if st.dragging then st.dragging.drag(m.x, false) end
    end
    st.hover = m.hover
    request_render()
end)

mp.observe_property("sub-margin-y", "number", function(_, v)
    -- 不是本脚本改的（比如用户自己调了），就当作新的基准值
    if v and not st.own_margins[v] then
        st.base_margin = v
        st.applied_margin = v
        st.own_margins = { [v] = true }
    end
end)

mp.register_event("shutdown", function()
    if st.base_margin and st.applied_margin ~= st.base_margin then
        mp.set_property_number("sub-margin-y", st.base_margin)
    end
end)

mp.register_script_message("toast", function(str, icon_name)
    toast(str or "", ICONS[icon_name or ""] and icon_name or "info")
end)

local VIS_LABEL = { auto = "控制栏：自动隐藏", always = "控制栏：常驻", never = "控制栏：隐藏" }
mp.add_key_binding(nil, "cycle-visibility", function()
    local next_mode = { auto = "always", always = "never", never = "auto" }
    o.visibility = next_mode[o.visibility] or "auto"
    toast(VIS_LABEL[o.visibility], "menu")
end)

options.read_options(o, "mochi", function()
    update_colors()
    request_render()
end)
update_colors()
mp.set_property_native("user-data/mochi/loaded", true)
