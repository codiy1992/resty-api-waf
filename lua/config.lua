local _M = {
    ["modules"] = {
        ["filter"] = {
            ["enable"] = true,
            ["rules"] = {
                {["matcher"] = 'any', ["by"] = "ip:in_list", ["action"] = "block", ["code"] = 403, ["enable"] = true },
                {["matcher"] = 'any', ["by"] = "device:in_list", ["action"] = "block", ["code"] = 403, ["enable"] = true },
                {["matcher"] = 'any', ["by"] = "uid:in_list", ["action"] = "block", ["code"] = 403, ["enable"] = true },
                {["matcher"] = 'attack_sql', ["action"] = "block", ["code"] = 403, ["enable"] = true },
                {["matcher"] = 'attack_file_ext', ["action"] = "block", ["code"] = 403, ["enable"] = true },
                {["matcher"] = 'attack_agent', ["action"] = "block", ["code"] = 403, ["enable"] = true },
                {["matcher"] = 'app_id', ["action"] = "block", ["code"] = 403, ["enable"] = false },
                {["matcher"] = 'app_version', ["action"] = "block", ["code"] = 403, ["enable"] = false },
            },
        },
        ["limiter"] = {
            ["enable"] = true,
            ["rules"] = {
                {["matcher"] = 'any', ["by"] = "ip", ["time"] = 60, ["count"] = 60, ["code"] = 403, ["enable"] = false },
                {["matcher"] = 'any', ["by"] = "uri", ["time"] = 60, ["count"] = 60, ["code"] = 403, ["enable"] = false },
                {["matcher"] = 'any', ["by"] = "ip,uri", ["time"] = 60, ["count"] = 60, ["code"] = 403, ["enable"] = false},
            }
        },
        ["counter"] = {
            ["enable"] = true,
            ["rules"] = {
                {["matcher"] = 'any', ["by"] = "ip",["time"] = 60, ["enable"] = false },
                {["matcher"] = 'any', ["by"] = "ip,uri", ["time"] = 60, ["enable"] = false },
            }
        },
        ["manager"] = {
            ["enable"] = true,
            ["auth"] = {
                ["user"] = "waf",
                ["pass"] = "TTpsXHtI5mwq",
            },
        },
    },
    ["matcher"] = {
        ["any"] = {},
        ["attack_sql"] = {
            ["Args"] = {
                ['name_operator'] = "*",
                ['operator'] = "≈",
                ['value']="select.*from",
            },
        },
        ["attack_file_ext"] = {
            ["URI"] = {
                ['operator'] = "≈",
                ['value']="\\.(htaccess|bash_history|ssh|sql)$",
            },
        },
        ["attack_agent"] = {
            ["UserAgent"] = {
                ['operator'] = "≈",
                ['value']="(nmap|w3af|netsparker|nikto|fimap|wget)",
            },
        },
        ["app_id"] = {
            ["Header"] = {
                ["name_operator"] = "=",
                ["name_value"] = "x-app-id",
                ["operator"] = "#",
                ["value"] = {
                    0
                },
            }
        },
        ["app_version"] = {
            ["Header"] = {
                ["name_operator"] = "=",
                ["name_value"] = "x-app-version",
                ["operator"] = "#",
                ["value"] = {
                    "0.0.0",
                },
            }
        },
    },
    ["response"] = {
        ["403"] = {
            ["status"] = 403,
            ["mime_type"] = "application/json",
            ["body"] = '{"code":"403", "message":"403 Forbidden"}',
        },
    },
}

return _M
