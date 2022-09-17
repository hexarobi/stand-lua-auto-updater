# Stand Lua Auto-Updater

A lib file to make auto-updating script files easy. Relies on [ETags](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/ETag) for version checks.

## Quick Start

Add this snippet near the top of your Lua Script, edit the `auto_update_source_url` field with the URL of the raw version of your main script file.
Make sure your script file begins with a comment (Ex: `-- MyScript`) or modify the `verify_file_begins_with="--"` parameter.
Thats it! On every run, your script will make a quick version check to GitHub, and if found replace the current script and restart.

```lua
local auto_update_source_url = "https://raw.githubusercontent.com/MyUsername/MyProjectName/main/MyScriptName.lua"

-- Auto Updater from https://github.com/hexarobi/stand-lua-auto-updater
local status, auto_updater = pcall(require, "auto-updater")
if not status then
    local auto_update_complete = nil util.toast("Installing auto-updater...", TOAST_ALL)
    async_http.init("raw.githubusercontent.com", "/hexarobi/stand-lua-auto-updater/main/auto-updater.lua",
        function(result, headers, status_code)
            local function parse_auto_update_result(result, headers, status_code)
                local error_prefix = "Error downloading auto-updater: "
                if status_code ~= 200 then util.toast(error_prefix..status_code, TOAST_ALL) return false end
                if not result or result == "" then util.toast(error_prefix.."Found empty file.", TOAST_ALL) return false end
                filesystem.mkdir(filesystem.scripts_dir() .. "lib")
                local file = io.open(filesystem.scripts_dir() .. "lib\\auto-updater.lua", "wb")
                if file == nil then util.toast(error_prefix.."Could not open file for writing.", TOAST_ALL) return false end
                file:write(result) file:close() util.toast("Successfully installed auto-updater lib", TOAST_ALL) return true
            end
            auto_update_complete = parse_auto_update_result(result, headers, status_code)
        end, function() util.toast("Error downloading auto-updater lib. Update failed to download.", TOAST_ALL) end)
    async_http.dispatch() local i = 1 while (auto_update_complete == nil and i < 10) do util.yield(250) i = i + 1 end
    if auto_update_complete == nil then error("Error downloading auto-updater lib. HTTP Request timeout") end
    auto_updater = require("auto-updater")
end
auto_updater.run_auto_update({source_url=auto_update_source_url, script_relpath=SCRIPT_RELPATH, verify_file_begins_with="--"})
```

For a more detailed explaination of what this snippet does, see [Quick Start Snippet Explained](#quick-start-snippet-explained)

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

#### Example multiple files

Example from HornSongs, loading many `*.horn` files into the store folder.
If the file isn't used at startup time you can set `auto_restart=false` to avoid restarting after an update.
These horn files are only used when a player selects them, so I set `auto_restart=false`.

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
        source_url="https://raw.githubusercontent.com/hexarobi/stand-lua-hornsongs/main/"..file_relpath,
        script_relpath=file_relpath,
        auto_restart=false,
        verify_file_begins_with="{",
    })
end
```

#### Example multiple `require()` script files

`run_auto_update()` does NOT require the files, just downloads/updates them, so to use the updated files you must still require them separately. 
You can optionally `util.yield()` between running run_auto_update() and require() to allow any downloads to complete to avoid potential error messages.
You can modify the time the script will wait after an update before restarting with the `restart_delay` parameter.

```lua
-- Define list of lib files
local lib_files = {
  "vehicle-constants",
  "vehicle-hashes",
}

-- Call auto-updater for each file
for _, lib_file in pairs(lib_files) do
    local file_relpath = "lib/"..lib_file..".lua"
    run_auto_update({
        source_url="https://raw.githubusercontent.com/hexarobi/stand-lua-constants/main/"..file_relpath,
        script_relpath=file_relpath,
        verify_file_begins_with="--",
    })
end

-- You can optionally pause here for the `restart_delay` period to avoid any misleading errors while the scripts are updating
-- If updates are found the script will be auto-restarted but any error messages in between can lead to confusion
-- The downside is your script will always take this additional time during startup
-- util.yield(3000)

-- Updates have finished applying and now the script is running normally, so require the files and continue as normal
for _, lib_file in pairs(lib_files) do
    require(lib_file)
end
```

#### Example dev branch picker

Sometimes you want to keep a very stable main branch release, while allowing beta testers to acces a development branch.
This can be accomplished by adding the configuration as shown below.

```lua
-- Increment script version for every release, to any branch.
local SCRIPT_VERSION = "1.0"    -- Ex dev value: 2.0b1
-- Define supported branches for your project, these much match branches created within github
local AUTO_UPDATE_BRANCHES = {
    { "main", {}, "More stable, but updatbed less often.", "main", },
    { "dev", {}, "Cutting edge updates, but less stable.", "dev", },
}
-- When this file is run, it will auto-update to the selected branch
-- When commiting this file to a branch, make sure this index matches the branch
local SELECTED_BRANCH_INDEX = 1     -- Ex dev value: 2

-- Replaces the normal run_auto_update() call
local function auto_update_branch(selected_branch)
    local branch_source_url = auto_update_source_url:gsub("/main/", "/"..selected_branch.."/")
    run_auto_update({source_url=branch_source_url, script_relpath=SCRIPT_RELPATH, verify_file_begins_with="--"})
end
auto_update_branch(AUTO_UPDATE_BRANCHES[SELECTED_BRANCH_INDEX][1])

...

-- A Script Meta menu with Release Branch picker
local script_meta_menu = menu.list(menu.my_root(), "Script Meta")
menu.readonly(script_meta_menu, "Version", SCRIPT_VERSION)
menu.list_select(script_meta_menu, "Release Branch", {}, "Switch release branches to beta test new features.", AUTO_UPDATE_BRANCHES, SELECTED_BRANCH_INDEX, function(index, menu_name, previous_option, click_type)
    if click_type ~= 0 then return end
    auto_update_branch(AUTO_UPDATE_BRANCHES[index][1])
end)
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

This verifies the file downloaded begins with the specified string.
This is a protection against any bugs or server errors that might return an invalid file.
I always start my Lua scripts with a comment including the name of the script, so I add verification the file begins with "--".

#### `verify_file_does_not_begin_with` (Optional, default="<")

This verifies the file downloaded DOES NOT begin with the specified string.
This is useful as a protection for HTML errors that begin with a "<" character.

#### `auto_restart` (Optional, default=true)

Should the script auto restart after applying an update. 
This is true by default, but can be disabled as needed, usually when loading many files,
tho you should finish up with one final update with restart to make sure all updates are applied.

#### `restart_delay` (Optional, default=2900)

The number of miliseconds to wait after an update has been applied before restarting the script.
If multiple files are being updated, this is needed to prevent restarting for each file.

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

## Quick Start Snippet Explained

Unpack the quick start snippet and explain the details of what is happening on each line.

```lua
-- Attempt to require the auto-updater lib. If successful continue as normal, if not, download and install it.
local status, auto_updater = pcall(require, "auto-updater")
if not status then
    -- Set a flag so we know when download and install has completed
    local auto_update_complete = nil
    -- Log a message that installation is beginning, both to the screen and to the log file
    util.toast("Installing auto-updater...", TOAST_ALL)
    -- Initialize an asynchronous HTTP GET request to the given host, and path.
    -- When completed, execute either the given success or error function.
    async_http.init(
        "raw.githubusercontent.com",    -- GitHub raw content is served from a content delivery network (CDN)
        "/hexarobi/stand-lua-auto-updater/main/auto-updater.lua",   -- Path to the auto-updater script hosted on github
        function(result, headers, status_code)  -- On Success handler
            -- Function to parse results and install lib and return success flag, or log a reason and return a failure flag
            local function parse_auto_update_result(result, headers, status_code)
                local error_prefix = "Error downloading auto-updater: " -- Many errors will need the same prefix to set it once
                -- A successful HTTP response is 200, anything else should be treated as an error
                if status_code ~= 200 then util.toast(error_prefix..status_code, TOAST_ALL) return false end
                -- A successful file download should have at least SOME content, an empty file should be treated as an error
                if not result or result == "" then util.toast(error_prefix.."Found empty file.", TOAST_ALL) return false end
                -- Make sure the lib folder is created if it doesnt exist already
                filesystem.mkdir(filesystem.scripts_dir() .. "lib")
                -- Open the script file for writing binary data
                local file = io.open(filesystem.scripts_dir() .. "lib\\auto-updater.lua", "wb")
                -- A successful update requires writing to the file, a failure to open the file for writing should be treated as an error
                if file == nil then util.toast(error_prefix.."Could not open file for writing.", TOAST_ALL) return false end
                -- Write the script contents to the file
                file:write(result)
                -- Close the file
                file:close()
                -- Log the successful update
                util.toast("Successfully installed auto-updater lib", TOAST_ALL)
                -- Return success flag
                return true
            end
            -- Run parse function and set the update response flag to the return value
            auto_update_complete = parse_auto_update_result(result, headers, status_code)
        end,
        function()  -- On Error Handler
            util.toast("Error downloading auto-updater lib. Update failed to download.", TOAST_ALL)
        end
    )
    -- Begin the HTTP request defined above
    async_http.dispatch()
    -- Initialize a counter
    local i = 1
    -- Loop until the counter reaches 40, or until a update response flag is set
    while (auto_update_complete == nil and i < 20) do
        -- Pause for 250ms before checking again
        util.yield(250)
        -- Increment counter
        i = i + 1
    end
    
    -- If we have waited 40 loops of 250ms (10 secs) without a reply, then error with a timeout
    if auto_update_complete == nil then 
        error("Error downloading auto-updater lib. HTTP Request timeout") 
    end
    
    -- The download and install has completed, so require the lib and continue with script execution
    auto_updater = require("auto-updater")
end
```
