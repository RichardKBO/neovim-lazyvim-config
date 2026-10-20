return {
  -- Tema padrao temporario.
  -- A preferencia salva em tema-atual.json tem prioridade.
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "retrobox",
    },
  },

  -- ========================================
  -- TEMAS EXISTENTES
  -- ========================================

  -- Tokyo Night
  {
    "folke/tokyonight.nvim",
    lazy = false,
    priority = 1000,
    opts = {},
  },

  -- Material
  {
    "marko-cerovac/material.nvim",
    lazy = false,
    priority = 1000,
    init = function()
      vim.g.material_style = "darker"
    end,
    opts = {},
  },

  -- Monokai Pro
  {
    "loctvl842/monokai-pro.nvim",
    lazy = false,
    priority = 1000,
    opts = {},
  },

  -- Dracula
  {
    "Mofiqul/dracula.nvim",
    lazy = false,
    priority = 1000,
  },

  -- Night Owl
  {
    "oxfist/night-owl.nvim",
    lazy = false,
    priority = 1000,
    opts = {},
  },

  -- Synthwave '84
  {
    "artanikin/vim-synthwave84",
    lazy = false,
    priority = 1000,
  },

  -- Horizon
  {
    "ntk148v/vim-horizon",
    lazy = false,
    priority = 1000,
  },

  -- Prism
  {
    "vimpostor/vim-prism",
    lazy = false,
    priority = 1000,
  },

  -- Omni
  {
    "getomni/neovim",
    lazy = false,
    priority = 1000,
  },

  -- Spaceduck
  {
    "pineapplegiant/spaceduck",
    lazy = false,
    priority = 1000,
  },

  -- ========================================
  -- NOVOS TEMAS ESCUROS
  -- ========================================

  -- Miasma
  {
    "xero/miasma.nvim",
    lazy = false,
    priority = 1000,
  },

  -- Melange
  {
    "savq/melange-nvim",
    lazy = false,
    priority = 1000,
  },

  -- Kanagawa: Wave e Dragon
  {
    "rebelot/kanagawa.nvim",
    lazy = false,
    priority = 1000,
    opts = {},
  },

  -- Oxocarbon: Dark
  {
    "nyoom-engineering/oxocarbon.nvim",
    lazy = false,
    priority = 1000,
    build = false,
  },

  -- Gruvbox Material
  {
    "sainnhe/gruvbox-material",
    lazy = false,
    priority = 1000,
    init = function()
      -- Contraste padrao
      vim.g.gruvbox_material_background = "medium"

      -- Paleta padrao
      vim.g.gruvbox_material_foreground = "material"

      -- Estilo oficial da statusline
      vim.g.gruvbox_material_statusline_style = "mix"
    end,
  },
}
