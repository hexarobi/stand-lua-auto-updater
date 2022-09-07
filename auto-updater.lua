-- Auto-Updater v1.5
-- by Hexarobi
-- For Lua Scripts for the Stand Mod Menu for GTA5
-- Example Usage:
--    require("auto-updater")
--    auto_update({
--        source_url="https://raw.githubusercontent.com/hexarobi/stand-lua-hornsongs/main/HornSongs.lua",
--        script_name=SCRIPT_NAME,
--        script_relpath=SCRIPT_RELPATH,
--    })

local function string_starts(String,Start)
    return string.sub(String,1,string.len(Start))==Start
end

local function read_version_id(auto_update_config)
    local file = io.open(auto_update_config.version_file)
    if file then
        local version = file:read()
        file:close()
        return version
    end
end

local function write_version_id(auto_update_config, version_id)
    local file = io.open(auto_update_config.version_file, "wb")
    if file == nil then
        util.toast("Error saving version id file: " .. auto_update_config.version_file)
    end
    file:write(version_id)
    file:close()
end

local function replace_current_script(auto_update_config, new_script)
    local file = io.open(auto_update_config.script_path, "wb")
    if file == nil then
        util.toast("Error updating "..auto_update_config.script_name..". Could not open file for writing.")
    end
    file:write(new_script.."\n")
    file:close()
end

local function restart_script(auto_update_config)
    -- simulate normal stop
    util.dispatch_on_stop()
    util.stop_all_threads()

    -- temporarily idling while Stand resets this environment
    util.keep_running()
    util.clear_commands_and_event_handlers()
    -- util.stop_all_threads()

    local c,e=loadfile(auto_update_config.script_path)
    if c then
        Stand_internal_coroutine_create(c)
    else
        util.toast(e, TOAST_ALL)
    end
end

local function ensure_script_store_dir_exists(auto_update_config)
    if not filesystem.exists(auto_update_config.script_store_dir) then
        filesystem.mkdir(auto_update_config.script_store_dir)
    end
end

local function join_path(parent, child)
    local sub = parent:sub(-1)
    if sub == "/" or sub == "\\" then
        return parent .. child
    else
        return parent .. "/" .. child
    end
end

local function expand_auto_update_config(auto_update_config)
    auto_update_config.script_clean_name = auto_update_config.script_name:gsub(".lua", "")
    auto_update_config.script_path = filesystem.scripts_dir() .. auto_update_config.script_relpath
    auto_update_config.script_store_dir = filesystem.store_dir() .. auto_update_config.script_clean_name .. '\\'
    ensure_script_store_dir_exists(auto_update_config)
    auto_update_config.version_file = join_path(auto_update_config.script_store_dir, "version.txt")
    if auto_update_config.source_url == nil then        -- For backward compatibility with older configs
        auto_update_config.source_url = "https://" .. auto_update_config.source_host .. "/" .. auto_update_config.source_path
    end
end

local function parse_url_host(url)
    return url:match("://(.-)/")
end

local function parse_url_path(url)
    return "/"..url:match("://.-/(.*)")
end

function auto_update(auto_update_config)
    expand_auto_update_config(auto_update_config)
    async_http.init(parse_url_host(auto_update_config.source_url), parse_url_path(auto_update_config.source_url), function(result, headers, status_code)
        if status_code == 304 then
            -- No update found
            return false
        end
        if not result or result == "" then
            util.toast("Error updating "..auto_update_config.script_name..". Found empty script file.")
            return false
        end
        -- Lua scripts should begin with a comment but other HTML responses will not
        if not string_starts(result, "--") then
            util.toast("Error updating "..auto_update_config.script_name..". Found invalid script file.")
            return false
        end
        replace_current_script(auto_update_config, result)
        if headers then
            for header_key, header_value in pairs(headers) do
                if header_key == "ETag" then
                    write_version_id(auto_update_config, header_value)
                end
            end
        end
        if auto_update_config.auto_restart ~= false then
            util.toast("Updated "..auto_update_config.script_name..". Restarting script...")
            util.yield(2000)    -- Avoid restart loops by giving time for any other scripts to also complete updates
            restart_script(auto_update_config)
        end
    end, function()
        util.toast("Error updating "..auto_update_config.script_name..". Update failed to download.")
    end)
    -- Use ETags to only fetch files if they have been updated
    -- https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/ETag
    local cached_version_id = read_version_id(auto_update_config)
    if cached_version_id then
        async_http.add_header("If-None-Match", cached_version_id)
    end
    async_http.dispatch()
end

-- Self-apply auto-update to this lib file
auto_update({
    source_url="https://raw.githubusercontent.com/hexarobi/stand-lua-auto-updater/main/auto-updater.lua",
    script_name="auto-updater.lua",
    script_relpath="lib/auto-updater.lua",
})
