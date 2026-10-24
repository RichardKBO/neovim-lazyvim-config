return {
  {
    "mfussenegger/nvim-jdtls",

    opts = function(_, opts)
      opts.settings = opts.settings or {}
      opts.settings.java = opts.settings.java or {}

      opts.settings.java.format = {
        enabled = true,

        settings = {
          url = vim.fs.joinpath(vim.fn.stdpath("config"), "formatters", "java-allman.xml"),

          profile = "JavaAllman",
        },
      }
    end,
  },
}
