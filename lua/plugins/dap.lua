-- Configuracao compartilhada do nvim-dap
-- Debuggers especificos ficam em languages/

return {
  {
    "mfussenegger/nvim-dap",

    keys = {
      {
        "<F5>",
        function()
          require("dap").toggle_breakpoint()
        end,
        desc = "Toggle Breakpoint",
      },

      {
        "<F7>",
        "<cmd>CMakeGenerate<cr>",
        desc = "CMake: Generate",
      },
    },

    opts = function()
      local dap = require("dap")

      -- CodeLLDB compartilhado por C, C++ e Rust
      -- A configuracao especifica do Rust foi movida
      -- para languages/rust/dap.lua.
      dap.adapters.codelldb = {
        type = "executable",

        command = vim.fn.expand("~/.local/share/codelldb/extension/adapter/codelldb"),
      }
    end,
  },

  {
    "rcarriga/nvim-dap-ui",

    dependencies = {
      "mfussenegger/nvim-dap",
    },

    config = function()
      local dap = require("dap")
      local dapui = require("dapui")

      dapui.setup()

      -- Abrir a interface ao iniciar o debugger.
      dap.listeners.after.event_initialized["dapui_config"] = function()
        dapui.open()
      end

      -- Fechar ao terminar a sessao.
      dap.listeners.before.event_terminated["dapui_config"] = function()
        dapui.close()
      end

      dap.listeners.before.event_exited["dapui_config"] = function()
        dapui.close()
      end
    end,
  },

  {
    "jay-babu/mason-nvim-dap.nvim",
    enabled = false,
  },
}
