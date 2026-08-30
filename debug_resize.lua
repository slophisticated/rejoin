-- debug_resize.lua
-- Calibrate the floating-window auto-arrange (2x2 grid per display.md) BEFORE relying on
-- it. Usage (Termux, repo dir):
--   lua debug_resize.lua          # print display size + computed grid targets only
--   lua debug_resize.lua --apply  # ALSO run the drag gestures (resize + move)
--
-- It prints, per configured clone:
--   * its configured grid cell (col,row)
--   * the target quadrant rectangle in px (from wm size + windowLayout)
--   * the CURRENT window rect it will assume (defaultRect or full-screen) and the
--     resize/move deltas it computes.
--
-- Because `dumpsys` does not list these App Cloner clones, the READBECK of the real
-- window rectangle is not available here. Use --apply and then eyeball/screenshot the
-- result; adjust config.windowLayout (handleInsetPx, titleGrabInsetY, defaultRect,
-- marginPx...) until each window lands where you want. The printed deltas tell you how
-- far each drag will go, which is the key number to sanity-check.

pcall(require, "core.logger")

local Config = require("core.config")
local Resize = require("managers.resize")

local _cfg = Config.get() or {}
local instances = _cfg.instances
if not instances or #instances == 0 then
    print("No instances configured.")
    os.exit(0)
end

local wl = type(_cfg.windowLayout) == "table" and _cfg.windowLayout or {}
local doApply = (arg and arg[1] == "--apply")

local disp = Resize.getDisplaySize()
if not disp then
    print("Could not read display size (wm size). Is the device connected / root?")
    os.exit(1)
end
print(string.format("Display size (px): %dx%d", disp.w, disp.h))
print(string.format("Grid: %sx%s  margin=%s  gap=%s", tostring(wl.cols or 2), tostring(wl.rows or 2),
    tostring(wl.marginPx or 20), tostring(wl.cellGapPx or 12)))
print("")

-- current-rect observer: defaultRect from config, else full-screen assumption.
local function observeCur(idx, inst)
    local d = wl.defaultRect
    if type(d) == "table" then
        return { left = d[1], top = d[2], right = d[3], bottom = d[4] }
    end
    return { left = tonumber(wl.defaultLeft) or 0, top = tonumber(wl.defaultTop) or 0,
             right = disp.w, bottom = disp.h }
end

local cols = tonumber(wl.cols) or 2
local rows = tonumber(wl.rows) or 2
local margin = tonumber(wl.marginPx) or 20
local gap = tonumber(wl.cellGapPx) or 12
local cellW = (disp.w - margin * 2 - gap * (cols - 1)) / cols
local cellH = (disp.h - margin * 2 - gap * (rows - 1)) / rows

local function cellRect(col, row)
    local left = math.floor(margin + (col - 1) * (cellW + gap))
    local top = math.floor(margin + (row - 1) * (cellH + gap))
    return { left = left, top = top, right = math.floor(left + cellW), bottom = math.floor(top + cellH) }
end

for idx, inst in ipairs(instances) do
    local grid = inst.grid
    local col = grid and tonumber(grid.col) or (((idx - 1) % cols) + 1)
    local row = grid and tonumber(grid.row) or (math.floor((idx - 1) / cols) + 1)
    local target = cellRect(col, row)
    local cur = observeCur(idx, inst)
    local dW = (target.right - target.left) - (cur.right - cur.left)
    local dH = (target.bottom - target.top) - (cur.bottom - cur.top)

    print(string.format("--- #%d %s (%s) cell=col%d,row%d ---",
        idx, tostring(inst.name or idx), tostring(inst.package), col, row))
    print(string.format("  target rect : (%d,%d)-(%d,%d)", target.left, target.top, target.right, target.bottom))
    print(string.format("  assumed cur : (%d,%d)-(%d,%d)", cur.left, cur.top, cur.right, cur.bottom))
    print(string.format("  resize delta: (%d,%d)  move-to top-left: (%d,%d)",
        dW, dH, target.left, target.top))
end

print("")
print("Keys to sanity-check:")
print("  1. target rect fits each quadrant (looks like display.md).")
print("  2. resize delta sign: + grows, - shrinks (handle bottom-right).")
print("  3. assumed 'cur' matches reality; if not set config.windowLayout.defaultRect /")
print("     defaultLeft/defaultTop so the relative drags start from the right spot.")
print("")

if doApply then
    print("Running drag gestures... (watch the windows)")
    Resize.layoutGrid(instances, observeCur)
    print("Done. Eyeball/screenshot to confirm each window landed in its quadrant.")
else
    print("Dry run only. Re-run with '--apply' to actually move/resize the windows.")
end
