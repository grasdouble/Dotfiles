if vim.fn.has('nvim-0.12') ~= 1 then
  error('This Neovim configuration requires Neovim 0.12 or newer.')
end

vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

vim.opt.number = true
vim.opt.relativenumber = false
vim.opt.mouse = 'a'
vim.opt.clipboard = 'unnamedplus'
vim.opt.undofile = true
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.signcolumn = 'yes'
vim.opt.updatetime = 250
vim.opt.scrolloff = 8
vim.opt.splitright = true
vim.opt.splitbelow = true
vim.opt.expandtab = true
vim.opt.shiftwidth = 2
vim.opt.tabstop = 2
vim.opt.termguicolors = true
vim.opt.completeopt = { 'menu', 'menuone', 'noselect' }
vim.opt.wildignore:append({ '**/node_modules/**', '**/.git/**', '**/target/**', '**/vendor/**' })

vim.api.nvim_create_autocmd('FileType', {
  pattern = { 'python', 'rust' },
  callback = function()
    vim.bo.expandtab = true
    vim.bo.shiftwidth = 4
    vim.bo.tabstop = 4
  end,
})

vim.api.nvim_create_autocmd('FileType', {
  pattern = 'go',
  callback = function()
    vim.bo.expandtab = false
    vim.bo.shiftwidth = 4
    vim.bo.tabstop = 4
  end,
})

local lazy_path = vim.fn.stdpath('data') .. '/lazy/lazy.nvim'
if not vim.uv.fs_stat(lazy_path) then
  if vim.fn.executable('git') ~= 1 then
    error('Git is required to install lazy.nvim.')
  end

  local output = vim.fn.system({
    'git', 'clone', '--filter=blob:none', '--branch=stable',
    'https://github.com/folke/lazy.nvim.git', lazy_path,
  })
  if vim.v.shell_error ~= 0 then
    error('Could not install lazy.nvim:\n' .. output)
  end
end

vim.opt.rtp:prepend(lazy_path)

local source_path = debug.getinfo(1, 'S').source
local config_file = source_path:sub(1, 1) == '@' and source_path:sub(2) or nil
config_file = config_file and (vim.uv.fs_realpath(config_file) or config_file)
if config_file then
  vim.opt.rtp:prepend(vim.fs.dirname(config_file))
end
local lockfile = config_file and (vim.fs.dirname(config_file) .. '/lazy-lock.json') or nil

require('lazy').setup(require('plugins'), {
  lockfile = lockfile,
  checker = { enabled = false },
  change_detection = { notify = false },
  rocks = { enabled = false },
  install = { colorscheme = { 'tokyonight' } },
})
if config_file then
  vim.opt.rtp:prepend(vim.fs.dirname(config_file))
end

vim.diagnostic.config({
  virtual_text = { spacing = 2, source = 'if_many' },
  signs = true,
  underline = true,
  update_in_insert = false,
  severity_sort = true,
  float = { border = 'rounded' },
})

vim.keymap.set('n', '<leader>e', '<cmd>Neotree toggle filesystem left<cr>', { desc = 'Toggle file tree' })
vim.api.nvim_create_autocmd('VimEnter', {
  callback = function()
    vim.cmd('Neotree show filesystem left')
  end,
})
vim.keymap.set('n', '<leader>ff', '<cmd>Telescope find_files<cr>', { desc = 'Find files' })
vim.keymap.set('n', '<leader>fg', '<cmd>Telescope live_grep<cr>', { desc = 'Search project' })
vim.keymap.set('n', '<leader>fb', '<cmd>Telescope buffers<cr>', { desc = 'Find buffers' })
vim.keymap.set('n', '<leader>gg', '<cmd>Git<cr>', { desc = 'Git status' })
vim.keymap.set('n', '<leader>f', function()
  require('conform').format({ async = false, lsp_format = 'never' })
end, { desc = 'Format buffer' })
