local RobloxLink = {}

-- Optional logger; falls back to print so this module also debugs standalone.
local loggerOK, Logger = pcall(require, "core.logger")
if not (loggerOK and Logger) then Logger = nil end
local function dbg(msg)
    if Logger and Logger.debug then
        Logger.debug(msg)
    else
        io.write("[roblox_link] " .. msg .. "\n")
    end
end

-- Validate a URL-ish string minimally so we don't pass junk to am start.
local function looksLikeUrl(url)
    if not url or type(url) ~= "string" then return false end
    url = url:match("^%s*(.-)%s*$")
    if url == "" then return false end
    -- Accept http(s) links and roblox:// / robloxmobile:// deep links. Reject obviously malformed strings.
    if not (url:lower():find("^https?://") or url:lower():find("^roblox://") or url:lower():find("^robloxmobile://")) then
        return false
    end
    -- The URL is embedded inside single quotes when passed to `am start`, so a single
    -- quote (or a backquote/$ expansion) could break out of the command string.
    -- `&`, `|`, `?` etc. are safe inside single quotes (private-server links use `&`).
    if url:find("['\"`$]") then
        return false
    end
    return true
end

-- Extract the raw place id from a Roblox game URL path segment.
local function extractPlaceId(url)
    -- https://www.roblox.com/games/<placeId>[/...]
    local lower = url:lower()
    if lower:find("roblox%.com/games/", 1, true) then
        local rest = url:match("games/(%d+)")
        if rest then return rest end
    end
    -- roblox://experiences/<placeId>
    if lower:find("roblox://experiences/", 1, true) then
        local rest = url:match("experiences/(%d+)")
        if rest then return rest end
    end
    return nil
end

-- Decide whether a link is a private-server /share link that must be kept as-is.
local function isShareLink(url)
    local lower = url:lower()
    return lower:find("roblox%.com/share", 1, true) ~= nil
end

-- Normalize a Roblox link to the safest form to hand to `am start VIEW`.
--
-- Rules:
--   * /share?code=...&type=Server (private server) is ALWAYS returned unchanged
--     (there is no placeId, the code determines the server; reshaping would break it).
--   * Public game links (https://www.roblox.com/games/<placeId> or
--     roblox://experiences/<placeId>) are converted to roblox://placeId=<placeId>.
--     On-device probing proved this form both auto-joins the map and (via -p <clone>
--     in Android.openURL) reaches the right per-account clone. Earlier forms
--     (robloxmobile://placeID=<id>, roblox://experiences/start?placeId=..., and forcing
--     -n ActivityProtocolLaunch) only opened the game's page on this client.
--   * Links we cannot identify are returned unchanged.
--
-- Returns (ok, normalized_url_or_err).
function RobloxLink.normalize(url)
    if not looksLikeUrl(url) then
        return false, "invalid_url"
    end

    local trimmed = url:match("^%s*(.-)%s*$")

    -- Private server share links must be preserved exactly.
    if isShareLink(trimmed) then
        return true, trimmed
    end

    -- Public game link -> deep link that auto-joins the map on the right clone/account.
    -- roblox://placeId=<id> is proven to auto-join and works per-clone when delivered
    -- with -p <clone> (see Android.openURL). Delivered via -p, so no default-handler issue.
    local placeId = extractPlaceId(trimmed)
    dbg("normalize url=" .. tostring(trimmed) .. " placeId=" .. tostring(placeId))
    if placeId then
        return true, string.format("roblox://placeId=%s", placeId)
    end

    -- Default: hand it back unchanged.
    return true, trimmed
end

return RobloxLink
