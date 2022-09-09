-- Auto-Updater v1.8
-- by Hexarobi
-- For Lua Scripts for the Stand Mod Menu for GTA5
-- https://github.com/hexarobi/stand-lua-auto-updater
-- Example Usage:
--    require("auto-updater")
--    auto_update({
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

local function ensure_directory_exists(path)
    local dirpath = ""
    for dirname in path:gmatch("[^/]+") do
        dirpath = dirpath .. dirname .. "/"
        if not filesystem.exists(dirpath) then
            filesystem.mkdir(dirpath)
        end
    end
end

local function expand_auto_update_config(auto_update_config)
    auto_update_config.script_relpath = auto_update_config.script_relpath:gsub("\\", "/")
    auto_update_config.script_path = filesystem.scripts_dir() .. auto_update_config.script_relpath
    auto_update_config.script_filename = ("/"..auto_update_config.script_relpath):match("^.*/(.+)$")
    auto_update_config.script_reldirpath = ("/"..auto_update_config.script_relpath):match("^(.*)/[^/]+$")
    ensure_directory_exists(filesystem.scripts_dir() .. auto_update_config.script_reldirpath)
    if auto_update_config.version_file == nil then
        auto_update_config.version_store_dir = filesystem.store_dir() .. "auto-updater" .. auto_update_config.script_reldirpath
        ensure_directory_exists(auto_update_config.version_store_dir)
        auto_update_config.version_file = auto_update_config.version_store_dir .. "/" .. auto_update_config.script_filename .. ".version"
    end
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

function run_auto_update(auto_update_config)
    expand_auto_update_config(auto_update_config)
    async_http.init(parse_url_host(auto_update_config.source_url), parse_url_path(auto_update_config.source_url), function(result, headers, status_code)
        if status_code == 304 then
            -- No update found
            return false
        end
        if not result or result == "" then
            util.toast("Error updating "..auto_update_config.script_filename..". Found empty script file.")
            return false
        end
        if auto_update_config.verify_file_begins_with ~= nil then
            if not string_starts(result, auto_update_config.verify_file_begins_with) then
                util.toast("Error updating "..auto_update_config.script_filename..". Found invalid script file.")
                return false
            end
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
            util.toast("Updated "..auto_update_config.script_filename)
            util.yield(2900)    -- Avoid restart loops by giving time for any other scripts to also complete updates
            util.toast("Restarting "..auto_update_config.script_filename)
            util.restart_script()
        end
    end, function()
        util.toast("Error updating "..auto_update_config.script_filename..". Update failed to download.")
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
end

-- Wrapper for old function name
function auto_update(auto_update_config)
    run_auto_update(auto_update_config)
end

-- Self-apply auto-update to this lib file
run_auto_update({
    source_url="https://raw.githubusercontent.com/hexarobi/stand-lua-auto-updater/main/auto-updater.lua",
    script_relpath="lib/auto-updater.lua",
})
