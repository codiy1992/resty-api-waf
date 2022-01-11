local _M = {}

local request_tester = require "lib.tester"

local limiter = ngx.shared.limiter

function _M.run(config)

    if ngx.req.is_internal() == true then
        return
    end

    if config.modules.limiter.enable ~= true then
        return
    end

    local matcher_list = config.matcher
    local response_list = config.response
    local response = nil

    for i, rule in ipairs( config.modules.limiter.rules ) do
        local enable = rule['enable']
        local matcher = matcher_list[ rule['matcher'] ]
        if enable == true and request_tester.test( matcher ) == true then

            -- IP block list
            if _M.existed( rule['separate'], 'ip_list' ) then
                local client_ip = _M.get_client_ip()
                if client_ip ~= nil and limiter:get(client_ip) ~= nil then
                    _M.response(response_list, rule)
                end
                goto continue
            end

            -- Device ID block list
            if _M.existed( rule['separate'], 'device_list' ) then
                local device_id = _M.get_device_id()
                if device_id ~= nil and limiter:get(string.lower(device_id)) ~= nil then
                    _M.response(response_list, rule)
                end
                goto continue
            end

            -- ip or uri request times limiting
            local key = i
            if _M.existed( rule['separate'], 'ip' ) then
                local client_ip = _M.get_client_ip()
                if client_ip == nil then
                    goto continue
                end
                key = key..'-'.._M.get_client_ip()
            end

            if _M.existed( rule['separate'], 'uri' ) then
                key = key..'-'..ngx.var.uri
            end

            local time = rule['time']
            local count = rule['count']
            local code = rule['code']

            local count_now = limiter:get(key)

            if count_now == nil then
                limiter:set( key, 1, tonumber(time) )
                count_now = 0
            end

            limiter:incr( key, 1 )

            if count_now > tonumber(count) then
                _M.response(response_list, rule)
            end
        end
        ::continue::
    end
end

function _M.response(response_list, rule)
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

function _M.get_client_ip()
    local ipv4 = ngx.req.get_headers()["X-Real-IP"]
    if ipv4 == nil then
        ipv4 = ngx.req.get_headers()["X-Forwarded-For"]
    end
    if ipv4 == nil then
        ipv4 = ngx.var.remote_addr
    end
    return ipv4
end

function _M.get_device_id()
    local headers = ngx.req.get_headers()
    for k,v in pairs(headers) do
        if string.lower(k) == 'x-device-id' then
            return string.lower(v)
        end
    end
    return
end

function _M.existed( list, value )
    for idx,item in ipairs( list ) do
        if item == value then
            return true
        end
    end
    return false
end

return _M
