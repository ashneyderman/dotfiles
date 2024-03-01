return {
  "nvim-treesitter/nvim-treesitter",
  opts = function(_, opts)
    -- add tsx and treesitter
    if type(opts) == "table" then
      vim.list_extend(opts.ensure_installed, {
        "elixir",
        "eex",
        "heex",
        "rust",
        "ron",
        "toml",
      })
    end
  end,
}
