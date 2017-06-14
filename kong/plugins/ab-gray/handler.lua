local BasePlugin = require "kong.plugins.base_plugin"
local ngx_log = ngx.log
local pairs = pairs
local tostring = tostring
local gray = require "kong.plugins.ab-gray.gray"
local com = require "kong.plugins.ab-gray.common"
local body_filter = require "kong.plugins.ab-gray.body_filter"
local balancer_execute = require("kong.core.balancer").execute

local AbGrayHandler = BasePlugin:extend()

function AbGrayHandler:new()
  AbGrayHandler.super.new(self, "ab-gray")
end

function AbGrayHandler:access(conf)
  AbGrayHandler.super.access(self)

  local balancer_address = ngx.ctx.balancer_address

  local upstream = ""
  local upstream_flag = com.read_key("upstream")
  
  ngx.ctx.gray_auth_redis = conf.redis or "127.0.0.1"
  local token = gray.verify_gray()
  if upstream_flag == "a" then
    upstream = conf.upstream_a
  else
    upstream = conf.upstream_b
  end
  
  balancer_address.host = upstream
  local ok, err = balancer_execute(balancer_address)
  if not ok then
    return responses.send_HTTP_INTERNAL_SERVER_ERROR(
      "failed the initial ".."dns/balancer resolve for '"..balancer_address.host..
        "' with: "..tostring(err))
  end

  ngx.ctx.balancer_address = balancer_address
  -- if set `host_header` is the original header to be preserved
  ngx.var.upstream_host = balancer_address.hostname..":"..balancer_address.port
  ngx.ctx.buffer = ""
end

function AbGrayHandler:header_filter(conf)
  AbGrayHandler.super.header_filter(self)
  
  if ngx.ctx.gray_header == "yes" then
    ngx.header.content_length = nil
    ngx.header.content_encoding = nil
  end
end


function AbGrayHandler:body_filter(conf)
  AbGrayHandler.super.body_filter(self)

  if ngx.status ~= 200 or ngx.ctx.gray_header ~= "yes" then
    local _, is_html = string.find(ngx.header["Content-Type"], "text/html")
    if is_html == nil then return end
  end
  
  local chunk, eof = ngx.arg[1], ngx.arg[2]
  if eof then
    local body = body_filter.add_finger(conf, ngx.ctx.buffer)
    ngx.arg[1] = body
  else
    ngx.ctx.buffer = ngx.ctx.buffer..chunk
    ngx.arg[1] = nil
  end  
end

  
return AbGrayHandler
