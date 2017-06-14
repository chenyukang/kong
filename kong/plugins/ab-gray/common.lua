local redis = require "resty.redis"

local charset = {}

-- qwertyuiopasdfghjklzxcvbnmQWERTYUIOPASDFGHJKLZXCVBNM1234567890
for i = 48,  57 do table.insert(charset, string.char(i)) end
for i = 65,  90 do table.insert(charset, string.char(i)) end
for i = 97, 122 do table.insert(charset, string.char(i)) end

local lang = {['en'] = true, ['ja'] = true, ['jp'] = true, ['zh-CN'] = true,
              ['zh'] = true, ['cn'] = true, ['de'] = true, ['fr'] = true,
              ['kr'] = true, ['ko'] = true, ['zh-TW'] = true, ['zh-tw'] = true, ['es'] = true}

local _M = {}

function _M.random_str(length)
  if length > 0 then
    return _M.random_str(length - 1) .. charset[math.random(1, #charset)]
  else
    return ""
  end
end

function _M.decode(str)
  local zlib = require "zlib"
  if unexpected_condition then error() end
  local stream = zlib.inflate()
  local ret = stream(str)
  return ret
end

function _M.writefile(filename, info)
  local file = io.open(filename, "ab")
  file:write(info)
  file:close()
end

function _M.readfile(filename)
  local file = io.open(filename, "rb")
  if file == nil then
    return nil
  end
  local data = file:read("*all")
  file:close()
  return data
end

function _M.readfinger(filename)
  local file = io.open(filename, "r")
  local data = file:read("*all")
  file:close()
  return data
end

function _M.seperate_uri(uri)
  local seps = {}
  local i = 1
  for w in string.gmatch(uri, '([^/]+)') do
    if lang[w] == nil then
      seps[i] = w
      i = i + 1
    end
  end
  return seps
end

function _M.in_table(tbl, item)
  for key, value in pairs(tbl) do
    if value == item then return true end
  end
  return false
end

function _M.read_key(key)
  ngx.log(ngx.ERR, "read redis key: ", key)
  local red = redis:new()
  red:set_timeout(2000) -- 2 sec

  local ok, err = red:connect("127.0.0.1", 6379)
  if not ok then
    ngx.log(ngx.ERR, "connect redis error", err)
    return nil
  end

  local ret, err = red:get(key)
  local ok, err = red:set_keepalive(10000, 80)
  if not ok then
    ngx.log(ngx.ERR, "failed to set keepalive: ", err)
    return nil
  end

  return ret
end


return _M