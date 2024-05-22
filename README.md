# Stand Lua Auto-Updater

A lib file to make auto-updating script files easy. Relies on [ETags](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/ETag) for version checks.

## Quick Start

1. First, add this snippet near the top of your Lua Script to auto-install the auto-updater script itself.

```lua
util.ensure_package_is_installed("lua/auto-updater")
local auto_updater = require("auto-updater")
```

2. Then add a call to `auto_updater.run_auto_update()`, passing a table of configuration options for your main script file.

```lua
auto_updater.run_auto_update({
    source_url="https://raw.githubusercontent.com/MyUsername/MyProjectName/main/MyScriptName.lua",
    script_relpath=SCRIPT_RELPATH,
})
```

The only required configuration is `source_url`, the URL for the raw version of your main script file.
The `script_relpath` must be set, but for the main script file this can be left as `SCRIPT_RELPATH` and will be automatically set by Stand.

3. That's it! Each day your script is run, it will make a quick check for an update, and if found replace the current script and restart.

### Additional Dependencies

If your project depends on additional files, you can include them as well in the `dependencies` list. 
If you supply a GitHub `project_url` and `branch` then the dependencies can simply be the `script_relpath` values and the rest will be assumed.

#### Example Auto-Updater with Dependencies
```lua
auto_updater.run_auto_update({
    source_url="https://raw.githubusercontent.com/hexarobi/stand-lua-context-menu/main/ContextMenu.lua",
    script_relpath=SCRIPT_RELPATH,
    project_url="https://github.com/hexarobi/stand-lua-context-menu",
    branch="main",
    dependencies={
        "lib/context_menu/constants.lua",
        "lib/context_menu/shared_state.lua",
        "lib/context_menu/vehicle_utils.lua",
    },
})
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
    auto_updater.run_auto_update({source_url=branch_source_url, script_relpath=SCRIPT_RELPATH, verify_file_begins_with="--"})
end
auto_update_branch(AUTO_UPDATE_BRANCHES[SELECTED_BRANCH_INDEX][1])

...

-- A Script Meta menu with Release Branch picker
local script_meta_menu = menu.list(menu.my_root(), "Script Meta")
menu.readonly(script_meta_menu, "Version", SCRIPT_VERSION)
menu.list_select(script_meta_menu, "Release Branch", {}, "Switch from main to dev to get cutting edge updates, but also potentially more bugs.", AUTO_UPDATE_BRANCHES, SELECTED_BRANCH_INDEX, function(index, menu_name, previous_option, click_type)
    if click_type ~= 0 then return end
    auto_update_config.switch_to_branch = AUTO_UPDATE_BRANCHES[index][1]
    auto_update_config.check_interval = 0
    auto_updater.run_auto_update(auto_update_config)
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

#### `project_url` (Optional, default=nil)

The GitHub project URL for your app. Required for using simple strings in the dependencies list.

#### `branch` (Optional, default=main)

The main git branch of your project. For most project this will be `main`.

#### `check_interval` (Optional, default=86400)

The number of seconds to wait after a success auto-update check, before doing another on startup.
Defaults to daily update checks.

#### `verify_file_begins_with` (Optional, default=nil)

This verifies the file downloaded begins with the specified string.
This is a protection against any bugs or server errors that might return an invalid file.
I always start my Lua scripts with a comment including the name of the script, so I add verification the file begins with "--".

#### `verify_file_does_not_begin_with` (Optional, default="<")

This verifies the file downloaded DOES NOT begin with the specified string.
This is useful as a protection for HTML errors that begin with a "<" character.

#### `http_timeout` (Optional, default=10000)

The HTTP timeout for loading the script, in miliseconds. Defaults to 10 seconds.

#### `expected_status_code` (Optional, default=200)

This verfies the updated data was returned with a 200 (Successful) status code

#### `silent_updates` (Optional, default=false)

If set to `true` then successful update messages wont be shown to the user. 
Any errors will still be shown. If set at the root config, this will also apply to all dependencies.

#### `auto_restart` (Optional, default=true)

Should the script auto restart after applying an update. 
This is true by default, but can be disabled as needed, usually when loading many files,
tho you should finish up with one final update with restart to make sure all updates are applied.

#### `restart_delay` (Optional, default=nil)

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
menu.my_root():action("Check for Update", {}, "The script will automatically check for updates at most daily, but you can manually check using this option anytime.", function()
    auto_update_config.check_interval = 0
    util.toast("Checking for updates")
    auto_updater.run_auto_update(auto_update_config)
end)
```
