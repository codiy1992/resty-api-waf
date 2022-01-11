local _M = {}
local cjson = require("cjson")
local shared = require("shared")

function _M.run(modules)
    local config = shared.get_config()
    for i, module in ipairs(modules) do
        require("modules." .. tostring(module)).run(config)
    end
end

function _M.save_config()
    local config = shared.get_config()
    local dkjson = require("lib.dkjson");
    local current_script_path = debug.getinfo(1, "S").source:sub(2)
    local home_path = current_script_path:sub( 1, 0 - string.len("/waf.lua") - 1 )
    local config_data = dkjson.encode( config, {indent = true})
    local config_dump_path = home_path .. "/config.json"
    local file, err = io.open( config_dump_path, "w")
    if file ~= nil then
        file:write(config_data)
        file:close()
    end
end

return _M
