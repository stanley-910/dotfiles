-- nvim-dap: core Debug Adapter Protocol client.
--
-- This deliberately installs only the protocol/client layer. Debug adapters are
-- configured per language (Python, JS/TS, etc.), and visual UI can be chosen
-- separately after the core workflow feels right.
--
-- Docs once installed:
--   :help dap.txt
--   :help dap-adapter
--   :help dap-configuration
--   :help dap-api
return {
  "mfussenegger/nvim-dap",
}
