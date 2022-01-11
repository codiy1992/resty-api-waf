

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
* /waf/config, 获取当前应用的配置
* /waf/config/reload, 立即更新配置

### 自定义配置

* 自定义配置存放在 redis 中以 `waf:config:` 为开头的`hset` 中
* 目前支持四个配置项, 硬编码在`shared.lua` 中, 分别为 `matcher`, `response`, `modules.filter.rules`, `modules.limiter.rules`

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

