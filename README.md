# Stand Lua Auto-Updater

A lib file to make auto-updating script files easy. Relies on [ETags](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/ETag) for version checks.

# Quick Start

Add this snippet to your Lua Script, edit the `source_url` field with the URL of the raw version of your main script file. Thats it!

```
local auto_update_config = {
    -- *** EDIT THIS LINE *** Update with the URL of your specific RAW script file
    source_url="https://raw.githubusercontent.com/MyUsername/MyProjectName/main/MyScriptName.lua",
    script_name=SCRIPT_NAME,                            -- No edit needed. `SCRIPT_NAME` will be set automatically by Stand.
    script_relpath=SCRIPT_RELPATH,                      -- No edit needed. `SCRIPT_RELPATH` will be set automatically by Stand.
}

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
    util.yield(3000)
end

require_or_download("auto-updater", "raw.githubusercontent.com", "/hexarobi/stand-lua-auto-updater/main/auto-updater.lua")
auto_update(auto_update_config)
```

# More Details

#### Require or Download Function

This adds a `require_or_download(library_name, source_host, source_path)` function so scripts will either 
include a lib if its already downloaded, or download and install it from GitHub.

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
    util.yield(3000)
end
```

#### Use require or download to install auto-updater lib

```lua
require_or_download("auto-updater", "raw.githubusercontent.com", "/hexarobi/stand-lua-auto-updater/main/auto-updater.lua")
```

#### Customize config for your script's raw source URL

```lua
local auto_update_config = {
    -- *** EDIT THIS LINE *** Update with the URL of your specific RAW script file
    source_url="https://raw.githubusercontent.com/MyUsername/MyProjectName/main/MyScriptName.lua",
    script_name=SCRIPT_NAME,                            -- No edit needed. `SCRIPT_NAME` will be set automatically by Stand.
    script_relpath=SCRIPT_RELPATH,                      -- No edit needed. `SCRIPT_RELPATH` will be set automatically by Stand.
}
```

#### Check for updates on script load

```lua
-- Check for updates anytime the script is run
auto_update(auto_update_config)
```

### Check for updates from a menu option

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
