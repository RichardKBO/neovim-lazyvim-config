return {
  {
    "nvim-lualine/lualine.nvim",

    opts = function(_, opts)
      local java = require("languages.java.statusline")

      opts.sections = opts.sections or {}
      opts.sections.lualine_x = opts.sections.lualine_x or {}

      table.insert(opts.sections.lualine_x, 1, {
        function()
          return java.texto()
        end,

        cond = function()
          return java.ativo()
        end,
      })
    end,
  },
}
