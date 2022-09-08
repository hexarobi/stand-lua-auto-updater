# Stand Lua Auto-Updater

A lib file to make auto-updating script files easy. Relies on [ETags](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/ETag) for version checks.

## Quick Start

Add this snippet near the top of your Lua Script, edit the `auto_update_source_url` field with the URL of the raw version of your main script file. Thats it!

```lua
local auto_update_source_url = "https://raw.githubusercontent.com/MyUsername/MyProjectName/main/MyScriptName.lua"
local status, lib = pcall(require, "auto-updater")
if not status then
    async_http.init("raw.githubusercontent.com", "/hexarobi/stand-lua-auto-updater/main/auto-updater.lua",
        function(result, headers, status_code) local error_prefix = "Error downloading auto-updater: "
            if status_code ~= 200 then util.toast(error_prefix..status_code) return false end
            if not result or result == "" then util.toast(error_prefix.."Found empty file.") return false end
            local file = io.open(filesystem.scripts_dir() .. "lib\\auto-updater.lua", "wb")
            if file == nil then util.toast(error_prefix.."Could not open file for writing.") return false end
            file:write(result) file:close() util.toast("Successfully installed auto-updater lib")
        end, function() util.toast("Error downloading auto-updater lib. Update failed to download.") end)
    async_http.dispatch() util.yield(3000) require("auto-updater")
end
run_auto_update({source_url=auto_update_source_url, script_relpath=SCRIPT_RELPATH})
```

### Additional files

If your project depends on additional files, you can setup auto_update calls for each file so that they 
will auto-install and auto-update as needed. The auto-updater even uses this internally on itself to apply updates.

#### Example single lib file

```lua
auto_update({
    source_url="https://raw.githubusercontent.com/hexarobi/stand-lua-auto-updater/main/auto-updater.lua",
    script_relpath="lib/auto-updater.lua",
})
```

#### Example multiple lib files

```lua
local root_source_url = "https://raw.githubusercontent.com/MyUsername/MyProjectName/main/"
local lib_files = {
    "lib/example1.lua",
    "lib/example2.lua"
}
for _, lib_file in pairs(lib_files) do
    auto_update({
        source_url=root_source_url..lib_file,
        script_relpath=lib_file,
    })
end
```

### Check for updates from a menu option

In addition to checking for updates at startup, you can optionally add
a menu item to kick off an update check.

```lua
-- Manually check for updates with a menu option
menu.action(menu.my_root(), "Check for Updates", {}, "Attempt to update to latest version", function()
    local updated = auto_update(auto_update_config)
    -- If update is applied script will be restarted so no response will return
    if not updated then
        util.toast("Already on latest version, no updates available.")
    end
end)
```
