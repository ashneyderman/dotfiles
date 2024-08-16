return {
  {
    "tpope/vim-fugitive",
  },
  {
    "lewis6991/gitsigns.nvim",
    opts = {
      signs = {
        add = { text = "+" },
        change = { text = "~" },
        delete = { text = "-" },
        topdelete = { text = "-" },
        changedelete = { text = ":" },
        untracked = { text = "?" },
      },
    },
  },
  {
    "f-person/git-blame.nvim",
    event = { "BufReadPre", "BufNewFile" },
    config = function()
      vim.g.gitblame_enabled = 1
      vim.g.gitblame_message_template = "<summary> • <date> • <author>"
      vim.g.gitblame_highlight_group = "LineNr"
    end,
  },
}
