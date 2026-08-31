local Logger = require("core.logger")
local AutoExecute = require("managers.autoexecute")

local CLI = {}

local function prompt(msg)
    io.write(msg)
    io.flush()
    return io.read()
end

-- Read multi-line script input from the terminal until a line that is exactly `END`
-- (the very last line). The `END` line is NOT stored / not executed.
local function readScript()
    local lines = {}
    while true do
        io.write("> ")
        io.flush()
        local line = io.read()
        if line == nil then return nil end                 -- EOF / Ctrl+D
        if line:match("^%s*END%s*$") then break end        -- terminal marker
        table.insert(lines, line)
    end
    return table.concat(lines, "\n") .. "\n"
end

local function printList()
    local list, err = AutoExecute.list()
    if not list then
        print("Could not list scripts: " .. tostring(err))
        return
    end
    if #list == 0 then
        print("(no scripts yet)")
        return
    end
    print(string.format("Scripts (%d):", #list))
    for _, s in ipairs(list) do
        print(string.format("  %-32s %6d bytes", s.name, s.size))
    end
end

-- Ask to continue adding more scripts ("Mau tambah lagi? (y/n)"). Returns true to add more.
local function wantMore()
    local a = prompt("Mau tambah lagi? (y/n): ") or ""
    return a:lower() == "y"
end

local function createFlow()
    while true do
        local name = prompt("Script name (no .lua): ") or ""
        name = name:match("^%s*(.-)%s*$")
        if name == "" then print("Name is required."); return end
        print("Tulis kode script. Akhiri dengan baris `END` di paling bawah, lalu Enter:")
        local content = readScript()
        if content == nil then print("Input dibatalkan (EOF)."); return end
        local ok, res = AutoExecute.save(name, content)
        if ok then
            print("Saved: " .. tostring(res))
        else
            print("Failed to save: " .. tostring(res))
            return
        end
        if not wantMore() then return end
    end
end

local function editFlow()
    printList()
    local name = prompt("Script name to overwrite (no .lua): ") or ""
    name = name:match("^%s*(.-)%s*$")
    if name == "" then print("Name is required."); return end
    print("Tulis kode baru. Akhiri dengan baris `END` di paling bawah, lalu Enter:")
    local content = readScript()
    if content == nil then print("Input dibatalkan (EOF)."); return end
    local ok, res = AutoExecute.save(name, content)
    if ok then print("Overwritten: " .. tostring(res)) else print("Failed: " .. tostring(res)) end
end

local function deleteFlow()
    printList()
    local name = prompt("Script name to delete (no .lua): ") or ""
    name = name:match("^%s*(.-)%s*$")
    if name == "" then print("Name is required."); return end
    local confirm = prompt("Are you sure? type 'yes' to confirm: ") or ""
    if confirm:lower() ~= "yes" then print("Aborted"); return end
    local ok, err = AutoExecute.remove(name)
    if ok then print("Deleted " .. name .. ".lua") else print("Failed to delete: " .. tostring(err)) end
end

local function deployFlow()
    local ok, res = AutoExecute.deployAll()
    if not ok then
        print("Deploy failed: " .. tostring(res))
    else
        print(string.format("Deployed %d script(s) to app.", res and res.okCount or 0))
        if res and res.errors and #res.errors > 0 then
            for _, e in ipairs(res.errors) do print("  - " .. tostring(e)) end
        end
    end
end

function CLI.run()
    while true do
        print("\nAutoExecute / Script Manager:\n  1) List scripts\n  2) Create script\n  3) Edit (overwrite) script\n  4) Delete script\n  5) Deploy scripts to app\n  6) Exit\n")
        local choice = prompt("Choose an option: ") or ""
        choice = choice:match("^%s*(.-)%s*$")
        if choice == "1" then
            printList()
        elseif choice == "2" then
            createFlow()
        elseif choice == "3" then
            editFlow()
        elseif choice == "4" then
            deleteFlow()
        elseif choice == "5" then
            deployFlow()
        elseif choice == "6" then
            print("Exiting AutoExecute Manager")
            break
        else
            print("Unknown choice")
        end
    end
end

return CLI
