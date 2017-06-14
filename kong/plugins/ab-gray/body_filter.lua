local com = require "kong.plugins.ab-gray.common"

local _M = {}

_M.finger = nil
                   
function _M.add_finger(conf, buffer)
  if _M.finger == nil then
    _M.finger = com.readfinger("/Users/yukang/code/kong/kong/plugins/ab-gray/finger.js")
  end

  local finger_js = string.gsub(_M.finger, "{expect_email}", ngx.ctx.gray_user)
  -- try to unzip
  local whole = buffer
  local status, debody = pcall(com.decode, buffer)
  if status then whole = debody end
  return whole..finger_js
end

return _M