local Errors = require "kong.dao.errors"

return {
  fields = { 
    upstream_a = { type = "string" },
    upstream_b = { type = "string" }
  },
  self_check = function(schema, plugin_t, dao, is_update)
    return true
  end
}
