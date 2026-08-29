local RobloxLink = {}

-- Validate a URL-ish string minimally so we don't pass junk to am start.
local function looksLikeUrl(url)
    if not url or type(url) ~= "string" then return false end
    url = url:match("^%s*(.-)%s*$")
    if url == "" then return false end
    -- Accept http(s) links and roblox:// deep links. Reject obviously malformed strings.
    if not (url:lower():find("^https?://") or url:lower():find("^roblox://")) then
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
-- Rules (non-destructive by default):
--   * Links we cannot identify are returned unchanged.
--   * /share?code=...&type=Server (private server) is ALWAYS returned unchanged.
--   * If allowNormalizeGame is true and the link is a public game link
--     (https://www.roblox.com/games/<placeId> or roblox://experiences/<placeId>),
--     it is converted to roblox://experiences/<placeId> for a more reliable deep link.
--   * Otherwise the link is returned unchanged.
--
-- Returns (ok, normalized_url_or_err).
function RobloxLink.normalize(url, allowNormalizeGame)
    if not looksLikeUrl(url) then
        return false, "invalid_url"
    end

    local trimmed = url:match("^%s*(.-)%s*$")

    -- Private server share links must be preserved exactly.
    if isShareLink(trimmed) then
        return true, trimmed
    end

    if allowNormalizeGame then
        local placeId = extractPlaceId(trimmed)
        if placeId then
            return true, string.format("roblox://experiences/%s", placeId)
        end
    end

    -- Default: hand it back unchanged.
    return true, trimmed
end

return RobloxLink
