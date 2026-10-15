return {
  -- Tema padrao temporario
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "retrobox",
    },
  },

  -- Tokyo Night
  {
    "folke/tokyonight.nvim",
    lazy = false,
    priority = 1000,
    opts = {},
  },

  -- Material Darker / Deep Ocean
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

  -- Spaceduck: alternativa espacial
  {
    "pineapplegiant/spaceduck",
    lazy = false,
    priority = 1000,
  },
}
