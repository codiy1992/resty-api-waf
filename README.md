

## 安装

### 依赖项(详见 Dockerfile)
* [OpenResty](https://openresty.org/cn/linux-packages.html)
* [Lua-Resty-JWT](https://github.com/SkyLothar/lua-resty-jwt)

### 使用示例

```shell
docker-compose up -d resty
```

## 说明

### 两个共享内存

* `lua_shared_dict waf 1m;` 存放 waf 配置等信息
* `lua_shared_dict limiter 10m;` 存放请求频率限制器信息

### 执行流程

* 1. `init_worker_by_lua` 阶段, 读入默认配置, 并从 redis 获取最新配置信息, 合并两者放入共享内存
* 2. `access_by_lua` 阶段, 从共享内存读取配置, 顺序执行对应模块

### 配置的结构

* `matcher` 一些匹配规则, 可在各模块间共用
* `response` 自定义响应格式, 可在各模块间共用
* `modules` 模块配置

### filter 模块

* 用于过滤请求uri, header 信息

### limiter 模块

* 用于建立请求频率限制
* 可设立仅针对IP的规则, 也可设立仅针对uri的规则, 默认为ip + uri 合并的规则

### manager 模块

* 用于 waf 的管理, 提供以 /waf 开头的路由, 需要进行 Basic Authorizaton 认证
* 默认账号密码 `waf:TTpsXHtI5mwq` 或者直接指定头信息 `Authorization: Basic d2FmOlRUcHNYSHRJNW13cQ==`
* `/waf/config`, 获取当前配置
* `/waf/config/refresh`, 立即更新配置
* `/waf/modules/limiter/refresh`, 立即更新ip/设备名单

### 默认配置

```json
{
    "response": { // 响应规则, 可新增可修改
        "403": { // code
            "mime_type": "application/json",
            "status": 403, // http status code
            "body": "{\"code\":\"403\", \"message\":\"403 Forbidden\"}"
        }
    },
    "matcher": { // 请求匹配器,可新增可修改, 可匹配Header, Args, URI, UserAgent, IP等
        "attack_sql": {
            "Args": {
                "operator": "≈", // 字符串是否包含value
                "value": "select.*from", // 字符串｜正则表达式
                "name_operator": "*"
            }
        },
        "attack_file_ext": {
            "URI": {
                "operator": "≈",
                "value": "\\.(htaccess|bash_history|ssh|sql)$"
            }
        },
        "attack_agent": {
            "UserAgent": {
                "operator": "≈",
                "value": "(nmap|w3af|netsparker|nikto|fimap|wget)"
            }
        },
        "app_id": {
            "Header": {
                "name_value": "x-app-id",
                "name_operator": "=",
                "operator": "#", // 过滤出x-app-id的值包含在value中的请求
                "value": [
                    0
                ]
            }
        },
        "app_version": {
            "Header": {
                "operator": "#",
                "name_value": "x-app-version", // 过滤出x-app-version的值包含在value中的请求
                "value": [
                    "0.0.0"
                ],
                "name_operator": "="
            }
        },
        "any": {} // 指代任意请求
    },
    "modules": {
        "manager": { // waf 接口的 Basic Authentication 账号密码
            "auth": {
                "pass": "TTpsXHtI5mwq",
                "user": "waf"
            },
            "enable": true
        },
        "filter": { // 请求过滤规则
            "enable": true,
            "rules": [
                { // 对于任意请求, 客户端IP包含在filter名单中的,执行block操作,返回403
                    "enable": true,
                    "action": "block",
                    "code": 403,
                    "by": "ip", // 可选值 ip|uid|device, 不指定则不使用`ngx.shared.filter`维护的名单
                    "matcher": "any"
                },
                { // 对于任意请求, 头信息X-Device-ID包含在filter名单中的,执行block操作,返回403
                    "enable": true,
                    "action": "block",
                    "code": 403,
                    "by": "device",
                    "matcher": "any"
                },
                { // 对于任意请求, Authorizaton UserID 包含在filter名单中的,执行block操作,返回403
                    "enable": true,
                    "action": "block",
                    "code": 403,
                    "by": "uid",
                    "matcher": "any"
                },
                { // 匹配attack_sql的请求并拒绝
                    "enable": true,
                    "action": "block",
                    "matcher": "attack_sql",
                    "code": 403
                },
                { // 匹配attack_file_ext的请求并拒绝
                    "enable": true,
                    "action": "block",
                    "matcher": "attack_file_ext",
                    "code": 403
                },
                {
                    "enable": true,
                    "action": "block",
                    "matcher": "attack_agent",
                    "code": 403
                },
                {
                    "enable": false,
                    "action": "block",
                    "matcher": "app_id",
                    "code": 403
                },
                {
                    "enable": false,
                    "action": "block",
                    "matcher": "app_version",
                    "code": 403
                }
            ]
        },
        "limiter": {
            "enable": true,
            "rules": [
                { // 匹配任意请求, 根据IP限制频率, 每60秒允许60次请求, 超过则拒绝
                    "matcher": "any",
                    "count": 60,
                    "code": 403,
                    "by": "ip", // 可选值 ip|uri|uid|device, 及其组合(以","间隔)
                    "time": 60,
                    "enable": false
                },
                { // 匹配任意请求, 根据uri限制频率, 每60秒允许60次请求, 超过则拒绝
                    "matcher": "any",
                    "count": 60,
                    "code": 403,
                    "by": "uri",
                    "time": 60,
                    "enable": false
                },
                { // 匹配任意请求, 根据ip,uri限制频率(即每个IP对每个URI每分钟限请求60次)
                    "matcher": "any",
                    "count": 60,
                    "code": 403,
                    "by": "ip,uri",
                    "time": 60,
                    "enable": false
                }
            ]
        },
        "counter": {
            "enable": true,
            "rules": [
                { // 匹配任意请求,统计每个IP对每个URI的请求次数
                    "enable": false,
                    "by": "ip,uri", // 可选值: ip|device|uid|uri 及其组合(以","间隔)
                    "time": 60, // 统计间隔 单位:秒
                    "matcher": "any"
                },
                {
                    "enable": false,
                    "by": "uid",
                    "time": 60,
                    "matcher": "any"
                }
            ]
        }
    }
}
```
### 自定义配置(通过Redis)

默认读取环境变量`REDIS_HOST`,`REDIS_PORT`,`REDIS_DB` 来获取redis配置, 否则从 `/data/.env` 读取

* 自定义配置存放在 redis 中以 `waf:config:` 为开头的`hset` 中
* 目前支持五个配置项, 硬编码在`shared.lua` 中, 分别为 `matcher`, `response`, `modules.manager`, `modules.filter.rules`, `modules.limiter.rules`
* 维护的IP名单和设备名单放在 redis `waf:modules:limiter` 的 `zset` 中

**0.维护IP/设备号名单**

```shell
// 限制设备号`X-Device-ID` = `f14268d542f919d5` 在到达Unix时间戳 `1664521948` 之前的访问
zadd waf:modules:filter 1664521948 f14268d542f919d5
// 限制IP `13.251.156.174` 在到达Unix时间戳 `1664521948` 之前的访问
zadd waf:modules:filter 1664521948 13.251.156.174
// 重载配置
curl --request POST '{YourDomain}/waf/modules/filter/reload' --header 'Authorization: Basic d2FmOlRUcHNYSHRJNW13cQ=='
```

**1. 修改 matcher**

可增加配置,也可修改默认配置

```shell
// 匹配头部参数 X-App-ID = 4 的请求
hset waf:config:matcher app_id '{"Header":{"operator":"#","name_value":"x-app-id","value":[4],"name_operator":"="}}'
// 匹配 UserAgent 包含 "postman" 的请求
hset waf:config:matcher attack_agent '{"UserAgent":{"value":"(postman)","operator":"≈"}}'
// 重载配置
curl --request POST '{YourDomain}/waf/config/refresh' --header 'Authorization: Basic d2FmOlRUcHNYSHRJNW13cQ=='
```
**2. 修改 response**

可增加配置,也可修改默认配置

```shell
// Redis 命令
hset waf:config:response 503 '{"status":503,"mime_type":"application/json","body":"{\"code\":\"503\", \"message\":\"Custom Message\"}"}'
// 重载配置
curl --request POST '{YourDomain}/waf/config/refresh' --header 'Authorization: Basic d2FmOlRUcHNYSHRJNW13cQ=='
```
**3. 修改 modules.filter.rules**

可增加配置,也可修改默认配置

```shell
// Redis 命令
hset waf:config:modules.filter.rules 0 '{"enable":true,"matcher":"app_id","action":"block","code":403}'
// 重载配置
curl --request POST '{YourDomain}/waf/config/refresh' --header 'Authorization: Basic d2FmOlRUcHNYSHRJNW13cQ=='
```

**4. 修改 modules.limiter.rules**

可增加配置,也可修改默认配置

```shell
// Redis 命令
hset waf:config:modules.limiter.rules 0 '{"time":"5","count":1,"enable":true,"code":503,"separate":["ip","uri"],"matcher":"apis"}'
// 重载配置
curl --request POST '{YourDomain}/waf/config/refresh' --header 'Authorization: Basic d2FmOlRUcHNYSHRJNW13cQ=='
```

**5. 修改 modules.manager**

```shell
// Redis 命令
hset waf:config:modules.manager auth '{"user": "test", "pass": "123" }'
// 重载配置
curl --request POST '{YourDomain}/waf/config/refresh' --header 'Authorization: Basic d2FmOlRUcHNYSHRJNW13cQ=='
```

### 参考项目

* [VeryNginx](https://github.com/alexazhou/VeryNginx)

---

## OpenResty 生命周期

## OpenResty 变量共享

### 模块里的变量

* 处于模块级别的变量在每个 worker 间是相互独立的，且在 worker 的生命周期中是只读的, 只在第一次导入模块时初始化.
* 模块里函数的局部变量,则在调用时初始化

### `ngx.var.*`

* [lua-nginx-module#ngxvarvariable](https://github.com/openresty/lua-nginx-module#ngxvarvariable)
* 使用代价较高
* 续先预定义才可使用(可在server 或 location 中定义)
* 类型只能是字符串
* 内部重定向会破坏原始请求的 `ngx.var.*` 变量 (如 `error_page`, `try_files`, `index` 等)

### `ngx.ctx.*`

* [lua-nginx-module#ngxctx](https://github.com/openresty/lua-nginx-module#ngxctx)
* 内部重定向会破坏原始请求的 `ngx.ctx.*` 变量 (如 `error_page`, `try_files`, `index` 等)

### `ngx.shared.DICT.*`

* 可在不同 worker 间共享数据
* [lua-nginx-module#ngxshareddict](https://github.com/openresty/lua-nginx-module#ngxshareddict)
* [data-sharing-within-an-nginx-worker](https://github.com/openresty/lua-nginx-module/#data-sharing-within-an-nginx-worker)


### `resty.lrucache`

* [lua-resty-lrucache](https://github.com/openresty/lua-resty-lrucache)
* 不同 worker 间数据相互隔离
* 同一 worker 不同请求共享数据

[https://github.com/openresty/lua-nginx-module/#data-sharing-within-an-nginx-worker](https://github.com/openresty/lua-nginx-module/#data-sharing-within-an-nginx-worker)

## table 与 metatable

[https://www.cnblogs.com/liekkas01/p/12728712.html](https://www.cnblogs.com/liekkas01/p/12728712.html)


## OpenResty LuaJIT2

* [https://github.com/openresty/luajit2#tablenkeys](https://github.com/openresty/luajit2#tablenkeys)

## Lua 手册

* [Lua 5.4](https://www.lua.org/manual/5.4/)

