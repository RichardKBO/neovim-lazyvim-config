-- Black Hole animado no Snacks Dashboard.
-- Preserva a paleta original e as configuracoes do Snacks.

local function restaurar_cores()
  local splash = require("milli").load("blackhole")
  local grupos = {}

  if not splash or not splash.colors then
    return
  end

  for _, frame in ipairs(splash.colors) do
    for _, row in ipairs(frame) do
      for _, run in ipairs(row) do
        local fg = run[3]
        local bg = run[4]

        local grupo = "MilliSplash_"
          .. fg:sub(2)
          .. "_"
          .. (bg == "NONE" and "NONE" or bg:sub(2))

        if not grupos[grupo] then
          vim.api.nvim_set_hl(0, grupo, {
            fg = fg,
            bg = bg ~= "NONE" and bg or nil,
          })

          grupos[grupo] = true
        end
      end
    end
  end
end

return {
  {
    "folke/snacks.nvim",

    dependencies = {
      "amansingh-afk/milli.nvim",
    },

    opts = function(_, opts)
      local splash = require("milli").load("blackhole")

      assert(
        splash and splash.frames and splash.frames[1],
        "Black Hole: primeiro quadro nao encontrado"
      )

      opts.dashboard = opts.dashboard or {}
      opts.dashboard.enabled = true
      opts.dashboard.preset = opts.dashboard.preset or {}

      opts.dashboard.preset.header =
        table.concat(splash.frames[1], "\n")
    end,

    config = function(_, opts)
      require("snacks").setup(opts)

      require("milli").snacks({
        splash = "blackhole",
        loop = true,
      })

      local grupo = vim.api.nvim_create_augroup(
        "BlackHoleCores",
        { clear = true }
      )

      vim.api.nvim_create_autocmd({
        "ColorScheme",
        "VimEnter",
      }, {
        group = grupo,
        callback = function()
          vim.schedule(restaurar_cores)
        end,
      })

      vim.schedule(restaurar_cores)
    end,
  },
}
