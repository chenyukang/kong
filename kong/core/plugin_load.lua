local cache = require "kong.tools.database_cache"
local responses = require "kong.tools.responses"
local singletons = require "kong.singletons"

-- Loads a plugin config from the datastore.
-- @return plugin config table or an empty sentinel table in case of a db-miss
local function load_plugin_into_memory(api_id, consumer_id, plugin_name)
  local rows, err = singletons.dao.plugins:find_all {
    api_id = api_id,
    consumer_id = consumer_id,
    name = plugin_name
                                                    }
  if err then
    return nil, err
  end

  if #rows > 0 then
    for _, row in ipairs(rows) do
      if api_id == row.api_id and consumer_id == row.consumer_id then
        return row
      end
    end
  end
  -- insert a cached value to not trigger too many DB queries.
  return {null = true}  -- works because: `.enabled == nil`
end

--- Load the configuration for a plugin entry in the DB.
-- Given an API, a Consumer and a plugin name, retrieve the plugin's
-- configuration if it exists. Results are cached in ngx.dict
-- @param[type=string] api_id ID of the API being proxied.
-- @param[type=string] consumer_id ID of the Consumer making the request (if any).
-- @param[type=stirng] plugin_name Name of the plugin being tested for.
-- @treturn table Plugin retrieved from the cache or database.
local function load_plugin_configuration(api_id, consumer_id, plugin_name)
  local cache_key = cache.plugin_key(plugin_name, api_id, consumer_id)
  local plugin, err = cache.get_or_set(cache_key, nil, load_plugin_into_memory,
                                       api_id, consumer_id, plugin_name)
  if err then
    responses.send_HTTP_INTERNAL_SERVER_ERROR(err)
  end
  if plugin ~= nil and plugin.enabled then
    return plugin.config or {}
  end
end


return load_plugin_configuration