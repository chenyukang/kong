local com = require "kong.plugins.ab-gray.common"
local finger = require "kong.plugins.ab-gray.finger"

local _M = {}

function _M.add_finger(conf, buffer)
  local finger_js = string.gsub(finger.js(), "{expect_email}", ngx.ctx.gray_user)
  -- try to unzip
  local whole = buffer
  local status, debody = pcall(com.decode, buffer)
  if status then whole = debody end
  return whole..finger_js
end

return _M