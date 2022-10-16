local _M = {}

local comm = require "lib.comm"
local request_tester = require "lib.tester"
local filter = ngx.shared.filter

function _M.run(config)
    if ngx.req.is_internal() == true then
        return
    end
    if config.modules.filter.enable ~= true then
        return
    end
    local matcher_list = config.matcher
    local response_list = config.response
    local response = nil

    for i,rule in ipairs(config.modules.filter.rules) do
        local enable = rule['enable']
        local matcher = matcher_list[ rule['matcher'] ]
        local action = rule['action']
        if enable == true and request_tester.test( matcher ) == true then
            if rule['by'] ~= nil and rule['by'] == 'ip' then
                local client_ip = comm.get_client_ip()
                if client_ip ~= nil and filter:get(client_ip) ~= nil then
                    if action ~= 'accept' then
                        comm.response(response_list, rule['code'])
                    end
                end
                goto continue
            end
            if rule['by'] ~= nil and rule['by'] == 'device' then
                local device_id = comm.get_device_id()
                if device_id ~= nil and filter:get(string.lower(device_id)) ~= nil then
                    if action ~= 'accept' then
                        comm.response(response_list, rule['code'])
                    end
                end
                goto continue
            end
            if rule['by'] ~= nil and rule['by'] == 'uid' then
                local uid = comm.get_user_id()
                if uid ~= nil and filter:get(string.lower(uid)) ~= nil then
                    if action ~= 'accept' then
                        comm.response(response_list, rule['code'])
                    end
                end
                goto continue
            end
            if action == 'accept' then
                goto continue
            else
                comm.response(response_list, rule['code'])
            end
        end
        ::continue::
    end
end

return _M
