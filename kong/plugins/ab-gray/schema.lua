return {
  fields = { 
    upstream_a = { required = true, type = "string" },
    upstream_b = { required = true, type = "string" },
    normal_upstream = {
      type = "string",
      default = "A",
      enum = { "A", "B" }
    }
  }
}
