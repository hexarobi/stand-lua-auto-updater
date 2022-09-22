-- Auto-Updater v1.12.1
-- by Hexarobi
-- For Lua Scripts for the Stand Mod Menu for GTA5
-- https://github.com/hexarobi/stand-lua-auto-updater
-- Example Usage:
--    auto_updater = require("auto-updater")
--    auto_updater.run_auto_update({
--        source_url="https://raw.githubusercontent.com/hexarobi/stand-lua-hornsongs/main/HornSongs.lua",
--        script_relpath=SCRIPT_RELPATH,  -- Set by Stand automatically for root script file, or can be used for lib files
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
        util.toast("Error updating "..auto_update_config.script_path..". Could not open file for writing.")
    end
    file:write(new_script.."\n")
    file:close()
end

local function expand_auto_update_config(auto_update_config)
    auto_update_config.script_relpath = auto_update_config.script_relpath:gsub("\\", "/")
    auto_update_config.script_path = filesystem.scripts_dir() .. auto_update_config.script_relpath
    auto_update_config.script_filename = ("/"..auto_update_config.script_relpath):match("^.*/(.+)$")
    auto_update_config.script_reldirpath = ("/"..auto_update_config.script_relpath):match("^(.*)/[^/]+$")
    filesystem.mkdirs(filesystem.scripts_dir() .. auto_update_config.script_reldirpath)
    if auto_update_config.version_file == nil then
        auto_update_config.version_store_dir = filesystem.store_dir() .. "auto-updater" .. auto_update_config.script_reldirpath
        filesystem.mkdirs(auto_update_config.version_store_dir)
        auto_update_config.version_file = auto_update_config.version_store_dir .. "/" .. auto_update_config.script_filename .. ".version"
    end
    if auto_update_config.source_url == nil then        -- For backward compatibility with older configs
        auto_update_config.source_url = "https://" .. auto_update_config.source_host .. "/" .. auto_update_config.source_path
    end
    if auto_update_config.restart_delay == nil then
        auto_update_config.restart_delay = 2900
    end
    if auto_update_config.http_timeout == nil then
        auto_update_config.http_timeout = 10000
    end
    if auto_update_config.expected_status_code == nil then
        auto_update_config.expected_status_code = 200
    end
end

local function parse_url_host(url)
    return url:match("://(.-)/")
end

local function parse_url_path(url)
    return "/"..url:match("://.-/(.*)")
end

function run_auto_update(auto_update_config)
    expand_auto_update_config(auto_update_config)
    local is_download_complete
    async_http.init(parse_url_host(auto_update_config.source_url), parse_url_path(auto_update_config.source_url), function(result, headers, status_code)
        if status_code == 304 then
            -- No update found
            is_download_complete = true
            return true
        end
        if status_code ~= auto_update_config.expected_status_code then
            util.toast("Error updating "..auto_update_config.script_filename..": Unexpected status code: "..status_code, TOAST_ALL)
            return false
        end
        if not result or result == "" then
            util.toast("Error updating "..auto_update_config.script_filename..": Empty content", TOAST_ALL)
            return false
        end
        if auto_update_config.verify_file_begins_with ~= nil then
            if not string_starts(result, auto_update_config.verify_file_begins_with) then
                util.toast("Error updating "..auto_update_config.script_filename..": Found invalid content", TOAST_ALL)
                return false
            end
        end
        if auto_update_config.verify_file_does_not_begin_with == nil then
            auto_update_config.verify_file_does_not_begin_with = "<"
        end
        if string_starts(result, auto_update_config.verify_file_does_not_begin_with) then
            util.toast("Error updating "..auto_update_config.script_filename..": Found invalid content", TOAST_ALL)
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
        is_download_complete = true
        if auto_update_config.auto_restart ~= false then
            util.toast("Updated "..auto_update_config.script_filename..". Restarting...", TOAST_ALL)
            util.yield(auto_update_config.restart_delay)  -- Avoid multiple restarts by giving other scripts time to complete updates
            util.restart_script()
        end
    end, function()
        util.toast("Error updating "..auto_update_config.script_filename..": Update failed to download.", TOAST_ALL)
    end)
    -- Only use cached version if the file still exists on disk
    if filesystem.exists(auto_update_config.script_path) then
        -- Use ETags to only fetch files if they have been updated
        -- https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/ETag
        local cached_version_id = read_version_id(auto_update_config)
        if cached_version_id then
            async_http.add_header("If-None-Match", cached_version_id)
        end
    end
    async_http.dispatch()
    local i = 1
    while (is_download_complete == nil and i < (auto_update_config.http_timeout / 500)) do
        util.yield(250)
        i = i + 1
    end
    if is_download_complete == nil then
        util.toast("Error updating "..auto_update_config.script_filename..": HTTP Timeout", TOAST_ALL)
        return false
    end
    return true
end

local function require_with_auto_update(auto_update_config)
    auto_update_config.lib_require_path = auto_update_config.script_relpath:gsub(".lua", "")
    if auto_update_config.auto_restart == nil then auto_update_config.auto_restart = false end
    local status, loaded_lib
    if (run_auto_update(auto_update_config)) then
        status, loaded_lib = pcall(require, auto_update_config.lib_require_path)
    end
    if not status then
        error("Failed to install auto-loaded lib: "..auto_update_config.script_relpath)
    end
    return loaded_lib
end

-- Wrapper for old function names
function auto_update(auto_update_config)
    run_auto_update(auto_update_config)
end

-- Self-apply auto-update to this lib file
util.create_thread(function()
    run_auto_update({
        source_url="https://raw.githubusercontent.com/hexarobi/stand-lua-auto-updater/main/auto-updater.lua",
        script_relpath="lib/auto-updater.lua",
        verify_file_begins_with="--",
    })
end)

return {
    run_auto_update = run_auto_update,
    require_with_auto_update = require_with_auto_update,
}

