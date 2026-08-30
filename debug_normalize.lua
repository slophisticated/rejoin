-- Debug: verify what utils/roblox_link.lua on THIS device actually produces for a
-- public game link, exactly as the tool uses it.
-- Run from the project root (~/rejoin):  lua debug_normalize.lua
package.path = "./?.lua;" .. (package.path or "")
local RobloxLink = require("utils.roblox_link")

print("searchpath:", package.searchpath("utils.roblox_link", package.path))
local src = debug.getinfo(RobloxLink.normalize, "S") and debug.getinfo(RobloxLink.normalize, "S").source
print("normalize source:", tostring(src))
print("=======")

local tests = {
    "https://www.roblox.com/games/107778070777162/Steal-An-Egg",
    "https://www.roblox.com/games/107778070777162",
    "roblox://placeId=107778070777162",
}

for _, url in ipairs(tests) do
    local ok, link = RobloxLink.normalize(url)
    print(string.format("IN : %s", url))
    print(string.format("OUT: ok=%s link=%s", tostring(ok), tostring(link)))
    print("---")
end
