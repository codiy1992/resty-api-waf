local _M = {}

local cjson = require("cjson")
local redis = require("lib.redis")
local nkeys = require("table.nkeys")

function _M.get_config()
    local config = ngx.shared.waf:get('config');
    if config ~= nil then
        return cjson.decode(config)
    end
    return nil
end

function _M.reload_config()
    local config = require('config');
    redis.exec(function (rds, config)
        local keys = {"matcher", "response", "modules.filter.rules", "modules.limiter.rules"}
        for i,key in pairs(keys) do

            local res, err = rds:hgetall("waf:config:"..key);
            if err then
                ngx.log(ngx.ERR, "failed:", err)
                goto continue
            end

            if next(res) == nil then
                goto continue
            end

            local sub_config = config
            local last_field = nil
            for field in string.gmatch(key, "%w+") do
                sub_config = sub_config[field]
                last_field = field
            end
            for i = 1,nkeys(res),2 do
                local name = tostring(res[i])
                local value = cjson.decode(res[i+1])
                if last_field == 'rules' then
                    table.insert(sub_config, value)
                else
                    sub_config[name] = value
                end
            end

            ::continue::
        end
    end, config)
    -- ngx.log(ngx.ERR, "---- config reloaded ----")
    ngx.shared.waf:set('config', cjson.encode(config))
    return config
end

function _M.reload_limited()
    redis.exec(function (rds)
        local res, err = rds:zrange("waf:modules:limiter", 0, -1, 'WITHSCORES');
        if err then
            ngx.log(ngx.ERR, "zrange failed:", err)
            return
        end
        local now = os.time(os.date("!*t"))
        for i = 1,nkeys(res),2 do
            local identifier = res[i]
            local expiry = tonumber(res[i+1])
            if expiry < now then
                rds:zrem("waf:modules:limiter", identifier)
            else
                ngx.shared.limiter:set(identifier, 999, expiry - now)
            end
        end

    end, config)
end

return _M
