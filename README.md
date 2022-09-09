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
run_auto_update({
    source_url="https://raw.githubusercontent.com/hexarobi/stand-lua-auto-updater/main/auto-updater.lua",
    script_relpath="lib/auto-updater.lua",
    verify_file_begins_with="--"
})
```

#### Example multiple lib files

```lua
local included_songs = {
    "au_claire_de_la_lune",
    "hot_cross_buns",
    "ode_to_joy",
    "scales",
    "twinkle_twinkle_little_star",
}
for _, included_song in pairs(included_songs) do
    local file_relpath = "store/HornSongs/songs/"..included_song..".horn"
    run_auto_update({
        source_url=SOURCE_BASE_URL..file_relpath,
        script_relpath=file_relpath,
        auto_restart=false,
    })
end
```

## Config Options

The `run_auto_update()` function accepts a table of options, which are described here.


#### `source_url`

The HTTP URL of the hosted source code for the script file to be downloaded. 
This MUST point to a CDN host that supports ETags, such as GitHub, or files will be re-updated every run.

#### `script_relpath`

The relative path from the `Stand/Lua Scripts/` directory to the the file to be added or updated by the source file.
For main scripts, the Stand built-in `SCRIPT_RELPATH` will work without any modification.
For dependency lib files, graphic files, etc... this can be further configured.

#### `verify_file_begins_with` (Optional, default=nil)

This verifies the file downloaded begins with the specified string before replacing the current file with it.
This is useful to make sure the script is never replaced by HTTP error messages etc...
I always start my scripts with a comment including the name of the script, so I just verify the file starts with "--".

#### `auto_restart` (Optional, default=true)

Should the script auto restart after applying an update. 
This is true by default, but can be disabled as needed, usually when loading many files,
tho you should finish up with one final update with restart to make sure all updates are applied.

#### `version_file` (Optional, default=Stand/Lua Scripts/store/auto-updater/{script_relpath}.version

The location of the version lock file for any particular file to be updated.
The content of this file is the ETag returned by the CDN, cached on disk, and sent in subsequent requests.
If nothing has been updated the CDN will return an empty 304 response,
if it has been updated the CDN will return a 200 response with the updated file.

### Check for updates from a menu option

In addition to checking for updates at startup, you can optionally add
a menu item to kick off an update check.

```lua
-- Manually check for updates with a menu option
menu.action(menu.my_root(), "Check for Updates", {}, "Attempt to update to latest version", function()
    local updated = run_auto_update(auto_update_config)
    -- If update is applied script will be restarted so no response will return
    if not updated then
        util.toast("Already on latest version, no updates available.")
    end
end)
```
