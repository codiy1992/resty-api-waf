local _M = {}

local request_tester = require "lib.tester"

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
        if enable == true and request_tester.test( matcher ) == true then
            local action = rule['action']
            if action == 'accept' then
                goto continue
            else
                if rule['response'] ~= nil then
                    response = response_list[tostring(rule['response'])]
                else
                    response = response_list[tostring(rule['code'])]
                end
                if response ~= nil then
                    ngx.status = tonumber(response['status'] or rule['code'])
                    ngx.header.content_type = response['mime_type']
                    ngx.say( response['body'] )
                    ngx.exit(ngx.HTTP_OK)
                else
                    if rule['code'] ~= nil then
                        ngx.exit( tonumber( rule['code'] ) )
                    else
                        ngx.exit(ngx.HTTP_SERVICE_UNAVAILABLE)
                    end
                end
            end
        end
        ::continue::
    end
end

return _M
