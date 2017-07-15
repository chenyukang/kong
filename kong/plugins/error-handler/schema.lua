return {
  fields = {
    config = { 
      type = "table",
      schema = {
        fields = {
          statuses = {type = "array", default = "", required = true},
          error_dir = {type = "string",  required = true}
        }
      }
    }
  }
}


