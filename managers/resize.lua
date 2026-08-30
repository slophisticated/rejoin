local Logger = require("core.logger")
local Shell = require("utils.shell")
local Config = require("core.config")
local Timer = require("utils.timer")

-- Auto-arrange the floating Roblox clones into a grid, per display.md: a 2x2 layout
-- with Clone1 top-left, Clone2 top-right, Clone3 bottom-left, Clone4 bottom-right.
--
-- The clones are App Cloner floating (freeform) windows. On this device `dumpsys
-- activity`/`dumpsys window` do NOT list them, so we cannot read a window's current
-- on-screen rectangle through the normal channels. Instead we simulate the same drag
-- gestures a human would make:
--   * drag the window's TITLE BAR  -> move it
--   * drag the BOTTOM-RIGHT handle -> resize it
-- via continuous `input motionevent DOWN -> MOVE... -> UP` strokes.
--
-- Because the starting rectangle of each window is not observable, this deliberately
-- works on RELATIVE drag distances from a known/default origin. Every geometric input
-- (title-bar grab point, resize-handle inset, grid margins, gesture length/step count)
-- is configurable under config.windowLayout so it can be calibrated on-device without
-- code changes.

local Resize = {}

-- Parse "wxh" (e.g. "1080x2340") from `wm size` output -> {w=...,h=...} or nil.
local function parseSize(s)
    if not s then return nil end
    -- prefer the explicit "Override size" / first "WxH" token; fall back to any WxH
    local w, h = s:match("(%d+)x(%d+)")
    if not w then return nil end
    return { w = tonumber(w), h = tonumber(h) }
end

-- Resolve the display size in pixels via `wm size`. Returns {w,h} or nil.
function Resize.getDisplaySize()
    local ok, _, out = pcall(function() return Shell.exec("wm size") end)
    if not ok or not out or out == "(dry-run)" then
        Logger.warn("Resize: could not read display size")
        return nil
    end
    return parseSize(out)
end

local function safeConf()
    local ok, conf = pcall(function() return Config.get() end)
    if not ok or type(conf) ~= "table" then conf = {} end
    local wl = conf.windowLayout
    if type(wl) ~= "table" then wl = {} end
    return conf, wl
end

-- Which grid cell an instance belongs to (from instance.grid or instance order).
local function gridCell(inst, index)
    if inst and type(inst.grid) == "table" and inst.grid.col and inst.grid.row then
        return tonumber(inst.grid.col) or 1, tonumber(inst.grid.row) or 1
    end
    -- fall back to positional (1=TL,2=TR,3=BL,4=BR -> col/row)
    local n = tonumber(index) or 1
    local col = ((n - 1) % 2) + 1
    local row = math.floor((n - 1) / 2) + 1
    return col, row
end

-- Compute the target quadrant rectangle for a (col,row) cell inside `disp` given the
-- layout margins (in px). Returns {left,top,right,bottom}.
local function cellRect(disp, wl, col, row)
    local cols = tonumber(wl.cols) or 2
    local rows = tonumber(wl.rows) or 2
    local margin = tonumber(wl.marginPx) or 20
    local vgap = tonumber(wl.cellGapPx) or 12
    local hgap = tonumber(wl.cellGapPx) or 12

    local totalW = disp.w
    local totalH = disp.h
    local cellW = (totalW - margin * 2 - hgap * (cols - 1)) / cols
    local cellH = (totalH - margin * 2 - vgap * (rows - 1)) / rows

    local left = math.floor(margin + (col - 1) * (cellW + hgap))
    local top = math.floor(margin + (row - 1) * (cellH + vgap))
    local right = math.floor(left + cellW)
    local bottom = math.floor(top + cellH)
    return { left = left, top = top, right = right, bottom = bottom }
end

-- Run a continuous drag gesture: DOWN at (x,y) then n MOVE steps to (tx,ty) then UP.
-- Uses motionevent for a smooth multi-point stroke (more reliable for long drags than a
-- single input swipe, which can be treated as a fling and dismissed).
local function dragGesture(x, y, tx, ty, steps, stepDelayMs)
    local cmdDown = string.format("input motionevent DOWN %d %d", x, y)
    local ok0, er0 = pcall(function() return Shell.exec(cmdDown) end)
    if not ok0 then Logger.warn("Resize: DOWN failed: " .. tostring(er0)) end
    Timer.sleep(stepDelayMs / 1000)

    steps = math.max(1, tonumber(steps) or 12)
    for i = 1, steps do
        local t = i / steps
        local cx = math.floor(x + (tx - x) * t)
        local cy = math.floor(y + (ty - y) * t)
        pcall(function() return Shell.exec(string.format("input motionevent MOVE %d %d", cx, cy)) end)
        Timer.sleep(stepDelayMs / 1000)
    end

    pcall(function() return Shell.exec(string.format("input motionevent UP %d %d", tx, ty)) end)
    Timer.sleep((tonumber(stepDelayMs) or 30) / 1000)
end

-- Drag the window's bottom-right resize handle from its current spot by (dx,dy).
-- Positive dx/dy grow the window. Assumes the handle is near the window's bottom-right.
local function resizeBy(handleX, handleY, dx, dy, wl)
    dragGesture(handleX, handleY, handleX + dx, handleY + dy,
        tonumber(wl.resizeSteps) or 12, tonumber(wl.stepDelayMs) or 30)
end

-- Drag the window by grabbing its title bar at (grabX,grabY) and moving it (dx,dy).
local function moveBy(grabX, grabY, dx, dy, wl)
    dragGesture(grabX, grabY, grabX + dx, grabY + dy,
        tonumber(wl.moveSteps) or 16, tonumber(wl.stepDelayMs) or 30)
end

-- Place one instance into its target cell. Because the window's current position is
-- unknown, callers pass the OBSERVED current window rect (from probe/calibration) as
-- `cur`. We then compute the resize delta (grow/shrink bottom-right) and the move delta
-- (drag from the title bar area) to reach `target`.
--
-- cur:      {left,top,right,bottom} of the window right now (px) -- calibration input.
-- target:   {left,top,right,bottom} desired rectangle (px) from cellRect().
-- wl:       windowLayout config (handle inset, grab point, step tuning).
function Resize.placeInstance(instance, cur, target, wl)
    if not cur or not target then
        Logger.warn("Resize.placeInstance: missing rects, skipping " .. tostring(instance and instance.name))
        return false
    end
    wl = wl or {}

    -- Bottom-right handle start point, inset from current window corner.
    local hInset = tonumber(wl.handleInsetPx) or 24
    local handleX = cur.right - hInset
    local handleY = cur.bottom - hInset

    -- Resize first so the window content doesn't jump under the title-bar drag origin.
    local dW = (target.right - target.left) - (cur.right - cur.left)
    local dH = (target.bottom - target.top) - (cur.bottom - cur.top)
    if math.abs(dW) > 2 or math.abs(dH) > 2 then
        Logger.debug(string.format("Resize: %s resize delta (%d,%d)", tostring(instance.name), dW, dH))
        resizeBy(handleX, handleY, dW, dH, wl)
    end

    -- After resize the origin moves; estimate the new top-left as if scaled from top-left
    -- anchor. Then drag the title bar by the remaining offset to the target top-left.
    local newLeft = cur.left
    local newTop = cur.top
    local grabInsetY = tonumber(wl.titleGrabInsetY) or 24
    local grabX = newLeft + math.floor((target.right - target.left) / 2)
    local grabY = newTop + grabInsetY
    local dX = target.left - newLeft
    local dY = target.top - newTop
    if math.abs(dX) > 2 or math.abs(dY) > 2 then
        Logger.debug(string.format("Resize: %s move delta (%d,%d)", tostring(instance.name), dX, dY))
        moveBy(grabX, grabY, dX, dY, wl)
    end
    return true
end

-- Convenience: lay out every instance into the 2x2 grid described by display.md.
-- `observeCur` is an optional function(index, instance) -> {left,top,right,bottom} used
-- to obtain each window's current rect (falls back to a default origin rect from config).
function Resize.layoutGrid(instances, observeCur)
    local disp = Resize.getDisplaySize()
    if not disp then return false end
    if not instances or #instances == 0 then return false end

    local conf, wl = safeConf()
    observeCur = observeCur or function() return nil end

    for idx, inst in ipairs(instances) do
        local col, row = gridCell(inst, idx)
        local target = cellRect(disp, wl, col, row)
        local cur = observeCur(idx, inst)
        if not cur then
            -- Default origin: App Cloner floating windows usually open near the top.
            -- Calibrate via windowLayout.defaultRect if the real default differs.
            local d = wl.defaultRect
            if type(d) == "table" then
                cur = { left = d[1], top = d[2], right = d[3], bottom = d[4] }
            else
                cur = { left = tonumber(wl.defaultLeft) or 0,
                        top = tonumber(wl.defaultTop) or 0,
                        right = disp.w, bottom = disp.h }
            end
        end
        Logger.info(string.format("Resize: placing %s at col=%d row=%d -> (%d,%d)-(%d,%d)",
            tostring(inst.name or inst.id), col, row,
            target.left, target.top, target.right, target.bottom))
        pcall(function() Resize.placeInstance(inst, cur, target, wl) end)
        Timer.sleep(0.4)
    end
    return true
end

return Resize
