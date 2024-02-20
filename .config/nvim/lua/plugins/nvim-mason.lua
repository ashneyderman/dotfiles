return {
  "williamboman/mason.nvim",
  opts = function(_, opts)
    if type(opts) == "table" then
      vim.list_extend(opts.ensure_installed, {
        "elixir-ls",
        "elp",
      })
    end
  end,
}
