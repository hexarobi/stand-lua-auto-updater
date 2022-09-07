# Stand Lua Auto-Updater

A lib file to make auto-updating script files easy. Relies on [ETags](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/ETag) for version checks.

# Installation

Add the following snippet to your Lua script. 
This adds a `require_or_download(library_name, source_host, source_path)` function so scripts will either 
include a lib if its already downloaded, or download and install it from GitHub.
Then uses that function to install the auto-updater lib.

```lua
local function require_or_download(lib_name, download_source_host, download_source_path)
    local status, lib = pcall(require, lib_name)
    if (status) then return lib end
    async_http.init(download_source_host, download_source_path, function(result, headers, status_code)
        local error_prefix = "Error downloading "..lib_name..": "
        if status_code ~= 200 then util.toast(error_prefix..status_code) return false end
        if not result or result == "" then util.toast(error_prefix.."Found empty file.") return false end
        local file = io.open(filesystem.scripts_dir() .. "lib\\" .. lib_name .. ".lua", "wb")
        if file == nil then util.toast(error_prefix.."Could not open file for writing.") return false end
        file:write(result) file:close()
        util.toast("Installed lib "..lib_name..". Stopping script...")
        util.yield(2000)        -- Pause to allow for other lib downloads to finish
        util.stop_script()      -- TODO: Change to restart instead of stop once added to util
    end, function() util.toast("Error downloading "..lib_name..". Update failed to download.") end)
    async_http.dispatch()
end

require_or_download("auto-updater", "raw.githubusercontent.com", "/hexarobi/stand-lua-auto-updater/main/auto-updater.lua")
```

# How to Use

Within your own Lua Script, add the following configuration


```lua
require("auto-updater")

local auto_update_config = {
    source_host="raw.githubusercontent.com",            -- If using GitHub this should stay `raw.githubusercontent.com`
    source_path="/username/project/main/MyScript.lua",  -- Edit this line to match your projects source URL path
    script_name=SCRIPT_NAME,                            -- No edit needed. `SCRIPT_NAME` will be set automatically by Stand.
    script_relpath=SCRIPT_RELPATH,                      -- No edit needed. `SCRIPT_RELPATH` will be set automatically by Stand.
}
```

You can then add checks for updates either automatically on every script run, or with a manual menu option, or both.


```lua
-- Check for updates anytime the script is run
auto_update(auto_update_config)
```

```lua
-- Manually check for updates with a menu option
menu.action(menu.my_root(), "Check for Update", {}, "Attempt to update to latest version", function()
    local updated = auto_update(auto_update_config)
    -- If update is applied script will be restarted so no response will return
    if not updated then
        util.toast("Already on latest version, no update available.")
    end
end)
```
