-- in visual mode move line under curose up and down
vim.keymap.set({ "v" }, "J", ":m '>+1<cr>gv=gv", { desc = "Move down" })
vim.keymap.set({ "v" }, "K", ":m '<-2<cr>gv=gv", { desc = "Move up" })
