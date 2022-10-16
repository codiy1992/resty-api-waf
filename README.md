

## 安装

### 依赖项(详见 Dockerfile)
* [OpenResty](https://openresty.org/cn/linux-packages.html)
* [Lua-Resty-JWT](https://github.com/SkyLothar/lua-resty-jwt)

### 使用示例

```shell
docker-compose up -d resty
```

## 说明

### 几个共享内存

* `lua_shared_dict waf 32k;` 存放 waf 配置等信息
* `lua_shared_dict list 10m;` 存放ip/device/uid名单, 可用于filter模块指定by参数如`ip:in_list`
* `lua_shared_dict limiter 10m;` 存放请求频率限制信息
* `lua_shared_dict counter 10m;` 存放请求次数统计信息

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

### counter 模块

* 统计请求次数
* 可根据ip,device,uid,uri及其任意组合如`ip,uri`, `uri,ip`,来统计
* 如设定`ip,uri`可以以同一IP下不同URI请求次数来观察请求
* 如设定`uri,ip`则以同一URI下不同IP的请求次数
* 如此类推

**查看请求计数器统计数据**

```shell
curl --location --request POST '127.0.0.1/waf/modules/counter/dump' \
--header 'Content-Type: application/json' \
--header 'Authorization: Basic d2FmOlRUcHNYSHRJNW13cQ==' \
--data-raw '{
    "count": 1, // 请求数量 >= 1, 当指定key时自动忽略
    "scale": 1024, // 数据规模设置为0可去全部统计数据,默认1024
    "by": "ip:172.23.0.1;uri", // 分组, 当指定key时自动忽略
    "time": 60, // 时间长度, 当指定key时自动忽略
    "key": "60;ip:172.23.0.1;uri:/waf/modules/counter/dump" // 完整的统计key
}'
```

### manager 模块

* 用于 waf 的管理, 提供以 /waf 开头的路由, 需要进行 Basic Authorizaton 认证
* 默认账号密码 `waf:TTpsXHtI5mwq` 或者直接指定头信息 `Authorization: Basic d2FmOlRUcHNYSHRJNW13cQ==`
* `/waf/status`, GET 获取状态信息
* `/waf/config`, GET 获取当前配置
* `/waf/config`, POST 临时变更配置, 在nginx重启前或执行`/waf/config/reload` 前有效
* `/waf/config/reload`, POST 立即更新配置
* `/waf/list/reload`, POST 立即更新ip/设备名单
* `/modules/counter/dump`, POST 输出请求计数器统计情况

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
                    "by": "ip:in_list", // 可选值 ip|uid|device + in_list|not_in_list, 不指定则不使用`ngx.shared.list`维护的名单
                    "matcher": "any"
                },
                { // 对于任意请求, 头信息X-Device-ID包含在filter名单中的,执行block操作,返回403
                    "enable": true,
                    "action": "block",
                    "code": 403,
                    "by": "device:in_list",
                    "matcher": "any"
                },
                { // 对于任意请求, Authorizaton UserID 包含在filter名单中的,执行block操作,返回403
                    "enable": true,
                    "action": "block",
                    "code": 403,
                    "by": "uid:in_list",
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

### 自定义配置(临时生效)

**nginx重启或者通过接口`/waf/config/reload`重载配置后天失效**

```shell
curl --request POST 'http://{YourDomain}/waf/config' \
--header 'Content-Type: application/json' \
--header 'Authorization: Basic d2FmOlRUcHNYSHRJNW13cQ==' \
--data-raw '{

    "modules": {
        "filter": {
            "rules": [
                {
                    "matcher": "any",
                    "action": "block",
                    "enable": true,
                    "by": "device:not_in_list"
                },
                {
                    "matcher": "any",
                    "action": "accept",
                    "enable": true,
                    "by": "device:in_list"
                }
            ]
        }
    }
}'
```

### 自定义配置(通过Redis)

默认读取环境变量`REDIS_HOST`,`REDIS_PORT`,`REDIS_DB` 来获取redis配置, 否则从 `/data/.env` 读取

* 自定义配置存放在 redis 中以 `waf:config:` 为开头的`hset` 中
* 目前支持六个配置项, 硬编码在`shared.lua` 中, 分别为 `matcher`, `response`, `modules.manager.auth`, `modules.filter.rules`, `modules.limiter.rules`, `modules.counter.rules`
* 维护的IP名单和设备名单放在 redis `waf:list` 的 `zset` 中

**0.维护IP/设备号名单**

```shell
// 示例一: 限制访问
// 限制设备号`X-Device-ID` = `f14268d542f919d5` 在到达Unix时间戳 `1664521948` 之前的访问
zadd waf:list 1664521948 f14268d542f919d5
// 限制IP `13.251.156.174` 在到达Unix时间戳 `1664521948` 之前的访问
zadd waf:list 1664521948 13.251.156.174
// 重载配置
curl --request POST '{YourDomain}/waf/list/reload' --header 'Authorization: Basic d2FmOlRUcHNYSHRJNW13cQ=='

// 示例二: 只允许在list中的IP访问
// 先排除
hset waf:config:modules.filter.rules 0 '{"matcher":"any","action":"block","enable":true,"by":"ip:not_in_list"}'
// 在包含
hset waf:config:modules.filter.rules 1 '{"matcher":"any","action":"accept","enable":true,"by":"ip:in_list"}'
// 添加名单
zadd waf:list 1664521948 13.251.156.174
// 载入名单
curl --request POST '{YourDomain}/waf/list/reload' --header 'Authorization: Basic d2FmOlRUcHNYSHRJNW13cQ=='
```

**1. 修改 matcher**

可增加配置,也可修改默认配置

```shell
// 匹配头部参数 X-App-ID = 4 的请求
hset waf:config:matcher app_id '{"Header":{"operator":"#","name_value":"x-app-id","value":[4],"name_operator":"="}}'
// 匹配 UserAgent 包含 "postman" 的请求
hset waf:config:matcher attack_agent '{"UserAgent":{"value":"(postman)","operator":"≈"}}'
// 重载配置
curl --request POST '{YourDomain}/waf/config/reload' --header 'Authorization: Basic d2FmOlRUcHNYSHRJNW13cQ=='
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
hset waf:config:modules.filter.rules 0 '{"matcher":"any","action":"block","enable":true,"by":"ip:not_in_list"}'
// 重载配置
curl --request POST '{YourDomain}/waf/config/reload' --header 'Authorization: Basic d2FmOlRUcHNYSHRJNW13cQ=='
```

**4. 修改 modules.limiter.rules**

可增加配置,也可修改默认配置

```shell
// Redis 命令
hset waf:config:modules.limiter.rules 0 '{"code":403,"count":60,"time":60,"matcher":"any","by":"ip","enable":true}'
// 重载配置
curl --request POST '{YourDomain}/waf/config/reload' --header 'Authorization: Basic d2FmOlRUcHNYSHRJNW13cQ=='
```

**5. 修改 modules.counter.rules**

可增加配置,也可修改默认配置

```shell
// Redis 命令
hset waf:config:modules.counter.rules 0 '{"matcher":"any","by":"ip,uri","time":60,"enable":true}'
// 重载配置
curl --request POST '{YourDomain}/waf/config/reload' --header 'Authorization: Basic d2FmOlRUcHNYSHRJNW13cQ=='
```

**6. 修改 modules.manager**

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

