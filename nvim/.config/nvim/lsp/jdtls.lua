local sdkman_dir = vim.env.SDKMAN_DIR
    or (vim.env.XDG_DATA_HOME and (vim.env.XDG_DATA_HOME .. "/sdkman"))
    or vim.fn.expand("~/.local/share/sdkman")

local java_21 = sdkman_dir .. "/candidates/java/21.0.11-zulu"
local java_17 = sdkman_dir .. "/candidates/java/17.0.19-zulu"

---@type vim.lsp.Config
return {
  cmd_env = {
    -- Force the language-server process itself to run on Java 21+; projects can
    -- still target Java 17 via `settings.java.configuration.runtimes` below.
    JAVA_HOME = java_21,
  },

  settings = {
    java = {
      configuration = {
        runtimes = {
          {
            name = "JavaSE-21",
            path = java_21,
            default = true,
          },
          {
            name = "JavaSE-17",
            path = java_17,
          },
        },
      },
    },
  },
}
