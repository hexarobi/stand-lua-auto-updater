# Stand Lua Auto-Updater

A lib file to make auto-updating script files easy. Relies on [ETags](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/ETag) for version checks.

# Installation

Copy the `auto-updater.lua` file to your `Stand/Lua Scripts/lib` directory.

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
