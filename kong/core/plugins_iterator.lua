local pl_tablex = require "pl.tablex"
local load_plugin_configuration = require "kong.core.plugin_load"
local empty = pl_tablex.readonly {}

--- Plugins for request iterator.
-- Iterate over the plugin loaded for a request, stored in
-- `ngx.ctx.plugins_for_request`.
-- @param[type=boolean] access_or_cert_ctx Tells if the context
-- is access_by_lua_block. We don't use `ngx.get_phase()` simply because we can
-- avoid it.
-- @treturn function iterator
local function iter_plugins_for_req(loaded_plugins, access_or_cert_ctx)
  local ctx = ngx.ctx

  ngx.log(ngx.ERR, "count int context: "..tostring(access_or_cert_ctx))
  if not ctx.plugins_for_request then
    ctx.plugins_for_request = {}
  end

  local i = 0

  local function get_next()
    i = i + 1
    local plugin = loaded_plugins[i]
    local api = ctx.api
    if plugin then
      -- load the plugin configuration in early phases
      if access_or_cert_ctx then

        local plugin_configuration

        -- Search API and Consumer specific, or consumer specific
        local consumer_id = (ctx.authenticated_consumer or empty).id        
        if consumer_id and plugin.schema and not plugin.schema.no_consumer then
          if api then
            plugin_configuration = load_plugin_configuration(api.id, consumer_id, plugin.name)
          end
          if not plugin_configuration then
            plugin_configuration = load_plugin_configuration(nil, consumer_id, plugin.name)
          end
        end

        if not plugin_configuration then
          -- Search API specific, or global
          if api then
            plugin_configuration = load_plugin_configuration(api.id, nil, plugin.name)
          end
          if not plugin_configuration then
            plugin_configuration = load_plugin_configuration(nil, nil, plugin.name)
          end
        end

        ctx.plugins_for_request[plugin.name] = plugin_configuration
      end

      -- return the plugin configuration
      if ctx.plugins_for_request[plugin.name] then
        return plugin, ctx.plugins_for_request[plugin.name]
      end

      return get_next() -- Load next plugin
    end
  end

  return get_next
end

return iter_plugins_for_req
