local BasePlugin = require "kong.plugins.base_plugin"
local pl_file = require "pl.file"
local pl_path = require "pl.path"

local ErrorHandler = BasePlugin:extend()

function ErrorHandler:new()
  ErrorHandler.super.new(self, "error-handler")
end

function ErrorHandler:error_handle(conf)
  ErrorHandler.super.error_handle(self)
  -- local found = false 
  -- for _, status in ipairs(conf.config.statuses) do
  --   if status == tostring(ngx.status) then
  --     found = true
  --     break
  --   end
  -- end
  -- if not found then return end
  local error_file = conf.config.error_dir .. "/" .. tostring(ngx.status) .. ".html"
  if pl_path.exists(error_file) then
    ngx.header["Content-Type"] = "text/html"
    local buffer = pl_file.read(error_file)
    ngx.ctx.error_done = true
    ngx.say(buffer)
    ngx.exit(ngx.status)
  else
    ngx.log(ngx.ERR, "error file does not exists: " .. error_file)
  end
end


return ErrorHandler