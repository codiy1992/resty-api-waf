local _M = {}

function _M.run(config)
    if config.modules.manager.enable ~= true then
        return
    end

    local base_uri = '/waf'
    if string.find(ngx.var.uri, base_uri) ~= 1 then
        return
    end

    _M.auth_check(config.modules.manager.auth)

    local uri = ngx.var.uri
    local method = ngx.req.get_method()
    local path = string.sub( ngx.var.uri, string.len( base_uri ) + 1 )
    for i,item in ipairs( _M.routes) do
        if method == item['method'] and path == item['path'] then
            ngx.header.content_type = "application/json"
            ngx.header.charset = "utf-8"
            ngx.say(item['handle'](config))
            ngx.exit(ngx.HTTP_OK)
        end
    end
    ngx.status = ngx.HTTP_NOT_FOUND
    ngx.header.content_type = "application/json"
    ngx.say('{"code": 404, "message":"Not Found"}')
    ngx.exit(ngx.HTTP_OK)
end

function _M.config(config)
    return require('cjson').encode(config)
end

function _M.refresh()
    return require('cjson').encode(require("shared").reload_config())
end

function _M.refresh_limiter()
    require("shared").reload_limited()
    return require('cjson').encode({["code"] = 200, ["message"] = "success"})
end

function _M.auth_check(auth)
    local token = nil
    local header = ngx.var.http_Authorization
    if header ~= nil then
        _, _, token = string.find(header, "Basic%s+(.+)")
    end
    if token ~= nil then
        token = ngx.decode_base64(token)
        if token == auth.user .. ":" .. auth.pass then
            return
        end
    end
    ngx.status = ngx.HTTP_UNAUTHORIZED
    ngx.header["WWW-Authenticate"] = [[Basic realm="restricted"]]
    ngx.say('{"code": 401, "message":"401 Unauthorized"}')
    ngx.exit(ngx.HTTP_OK)
    return
end

_M.routes = {
    { ['method'] = "GET", ["path"] = "/config", ['handle'] = _M.config},
    { ['method'] = "POST", ["path"] = "/config/refresh", ['handle'] = _M.refresh},
    { ['method'] = "POST", ["path"] = "/modules/limiter/refresh", ['handle'] = _M.refresh_limiter},
}

return _M
