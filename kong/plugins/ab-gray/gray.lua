local redis = require "resty.redis"
local com = require "kong.plugins.ab-gray.common"
local md5 = require "kong.plugins.ab-gray.md5"
local cjson = require "cjson"


local _M = {}

function _M.gen_random_token(gray_user)
  local time = os.time()
  local rand_str = com.random_str(20)
  local token = "gray_"..(md5.sumhexa(rand_str..time))

  local red = redis:new()
  red:set_timeout(2000) -- 2 sec
  local ok, err = red:connect(ngx.ctx.gray_auth_redis, 6379)

  if not ok then
    ngx.log(ngx.ERR, "connect redis error: ", err)
    return nil
  end

  -- write token into auth redis, with timeout
  ok, err = red:set(token, gray_user)
  if not ok then
    ngx.log(ngx.ERR, "redis write failed: ", err)
    return nil
  end

  -- 120 seconds ttl
  ok, err = red:expire(token, "120")
  if not ok  then
    ngx.log(ngx.ERR, "redis set timeout fialed: ", err)
    return nil
  end

  -- close redis connect status
  ok, err = red:set_keepalive(10000, 80)
  if not ok then
    ngx.log(ngx.ERR, "redis set_keepalive failed: ", err)
    return nil
  end

  return token
end


-- 检查清平的 view_gray cookie, 如果有根据其值再去 redis 里面取出凭证
function _M.verify_gray_from_cookie()
  if true then
    local user = "yukang.chen@dji.com"
    local gray_token = _M.gen_random_token(user)
    return user, gray_token
  end
  
  local view_gray = ngx.var.cookie_View_gray
  local traceid = ngx.var.cookie_Traceid
  if view_gray == nil or tostring(view_gray) == ""  or tostring(traceid) == "" then
    return nil, nil
  end

  local red = redis:new()
  red:set_timeout(2000) -- 2 sec
  local ok, err = red:connect(ngx.ctx.gray_auth_redis, 6379)
  if not ok then
    ngx.log(ngx.ERR, "connect redis error", err)
    return nil, nil
  end

  local json, _ = red:get(view_gray)
  local ok, err = red:set_keepalive(10000, 80)
  if not ok then
    ngx.log(ngx.ERR, "failed to set keepalive: ", err)
    return nil, nil
  end

  if (not json) or (json == ngx.null) then
    return nil, nil
  else
    local agent = ngx.req.get_headers()["User-Agent"]
    local content = cjson.decode(json)
    local trace = tostring(traceid or "")
    local decode = md5.sumhexa(agent..trace)
    local user = content["adname"]
    local sign = content["sign"]
    if decode ~= sign then return nil end
    local gray_token = _M.gen_random_token(user)
    if gray_token == nil then
      return nil, nil
    end
    ngx.log(ngx.ERR, "verify_from_cookie: ", user)
    return user, gray_token
  end
end

function _M.verify_from_header()
  local token = ngx.req.get_headers()["X-GRAY-TOKEN"]
  if token ~= nil and token ~= "" then
    local red = redis:new()
    red:set_timeout(2000) -- 2 sec
    local ok, err = red:connect(ngx.ctx.gray_auth_redis, 6379)
    if not ok then
      ngx.log(ngx.ERR, "connect redis error", err)
      return nil, nil
    end
    local user, _ = red:get(token)
    local ok, err = red:set_keepalive(10000, 80)
    if not ok then
      ngx.log(ngx.ERR, "failed to set keepalive: ", err)
      return nil, nil
    end
    if user ~= ngx.null and user ~= "" then
      ngx.log(ngx.ERR, "verify_from_header: ", user)
      return user, token
    end
  else
    return nil, nil
  end
end

function _M.verify_gray()
  -- 检查是否是公司出口，如果不是公司出口，不设置灰度访问
  -- whitelist 在 init_whitelist.lua 里面初始化
  -- if not iputils.ip_in_cidrs(ngx.var.remote_addr, whitelist) then
  --   return nil
  -- end

  local gray_user, token = _M.verify_from_header()
  if gray_user == nil then
    gray_user, token = _M.verify_gray_from_cookie()
  end
  if gray_user ~= nil then
    ngx.ctx.gray_user = gray_user
    ngx.ctx.gray_token = token
    ngx.ctx.gray_header = "yes"
    return gray_user
  end
  return nil
end

function _M.process_upstream(conf)
  ngx.ctx.gray_auth_redis = conf.redis or "127.0.0.1"
  local gray_user = _M.verify_gray()
  local upstream;
  if gray_user then
    upstream = (conf.normal_upstream == "A" and conf.upstream_b) or conf.upstream_a
  else
    upstream = (conf.normal_upstream == "A" and conf.upstream_a) or conf.upstream_b
  end
  return upstream
end

return _M