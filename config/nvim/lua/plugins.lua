local servers = {
  'vtsls',
  'eslint',
  'cssls',
  'html',
  'jsonls',
  'pyright',
  'ruff',
  'rust_analyzer',
  'gopls',
}

return {
  {
    'folke/tokyonight.nvim',
    lazy = false,
    priority = 1000,
    opts = { style = 'night' },
    config = function(_, opts)
      require('tokyonight').setup(opts)
      vim.cmd.colorscheme('tokyonight')
    end,
  },
  {
    'nvim-treesitter/nvim-treesitter',
    branch = 'main',
    lazy = false,
    build = ':TSUpdate',
    config = function()
      require('nvim-treesitter').setup({ install_dir = vim.fn.stdpath('data') .. '/site' })
      require('nvim-treesitter').install({
        'bash', 'css', 'go', 'gomod', 'gosum', 'html', 'javascript', 'json',
        'lua', 'markdown', 'markdown_inline', 'python', 'rust', 'tsx', 'typescript', 'vim', 'vimdoc',
      })

      vim.api.nvim_create_autocmd('FileType', {
        pattern = {
          'bash', 'css', 'go', 'gomod', 'gosum', 'html', 'javascript', 'javascriptreact',
          'json', 'lua', 'markdown', 'python', 'rust', 'typescript', 'typescriptreact', 'vim',
        },
        callback = function(args)
          pcall(vim.treesitter.start, args.buf)
        end,
      })
    end,
  },
  {
    'nvim-lua/plenary.nvim',
    lazy = true,
  },
  {
    'nvim-tree/nvim-web-devicons',
    lazy = true,
  },
  {
    'saghen/blink.cmp',
    version = '1.*',
    dependencies = { 'rafamadriz/friendly-snippets' },
    opts = {
      keymap = { preset = 'default' },
      appearance = { nerd_font_variant = 'mono' },
      completion = { documentation = { auto_show = true } },
      snippets = { preset = 'default' },
      sources = { default = { 'lsp', 'path', 'snippets', 'buffer' } },
    },
  },
  {
    'mason-org/mason.nvim',
    opts = {},
  },
  {
    'neovim/nvim-lspconfig',
    lazy = false,
  },
  {
    'mason-org/mason-lspconfig.nvim',
    dependencies = { 'mason-org/mason.nvim', 'neovim/nvim-lspconfig', 'saghen/blink.cmp' },
    config = function()
      local capabilities = require('blink.cmp').get_lsp_capabilities()

      for _, server in ipairs(servers) do
        vim.lsp.config(server, { capabilities = capabilities })
      end
      vim.lsp.config('vtsls', {
        settings = { vtsls = { autoUseWorkspaceTsdk = true } },
      })
      vim.lsp.config('pyright', {
        settings = {
          python = {
            analysis = {
              typeCheckingMode = 'basic',
              autoSearchPaths = true,
              useLibraryCodeForTypes = true,
            },
          },
        },
      })
      vim.lsp.config('rust_analyzer', {
        settings = { ['rust-analyzer'] = { check = { command = 'clippy' } } },
      })
      vim.lsp.config('gopls', {
        settings = {
          gopls = {
            analyses = { unusedparams = true },
            staticcheck = true,
            completeUnimported = true,
          },
        },
      })

      require('mason-lspconfig').setup({ automatic_enable = true })

      vim.api.nvim_create_autocmd('LspAttach', {
        callback = function(args)
          local map = function(lhs, rhs, desc)
            vim.keymap.set('n', lhs, rhs, { buffer = args.buf, desc = desc })
          end
          map('gd', vim.lsp.buf.definition, 'Go to definition')
          map('gr', vim.lsp.buf.references, 'Find references')
          map('K', vim.lsp.buf.hover, 'Hover documentation')
          map('<leader>rn', vim.lsp.buf.rename, 'Rename symbol')
          map('<leader>ca', vim.lsp.buf.code_action, 'Code action')
        end,
      })
    end,
  },
  {
    'WhoIsSethDaniel/mason-tool-installer.nvim',
    dependencies = { 'mason-org/mason.nvim', 'mason-org/mason-lspconfig.nvim' },
    opts = {
      ensure_installed = {
        'vtsls', 'eslint', 'cssls', 'html', 'jsonls', 'pyright', 'ruff', 'rust_analyzer', 'gopls',
        'prettierd', 'goimports', 'js-debug-adapter', 'debugpy', 'delve', 'codelldb',
      },
      auto_update = false,
      run_on_start = true,
      start_delay = 1000,
      debounce_hours = 24,
    },
  },
  {
    'stevearc/conform.nvim',
    opts = {
      formatters_by_ft = {
        javascript = { 'prettierd' },
        javascriptreact = { 'prettierd' },
        typescript = { 'prettierd' },
        typescriptreact = { 'prettierd' },
        css = { 'prettierd' },
        scss = { 'prettierd' },
        html = { 'prettierd' },
        json = { 'prettierd' },
        jsonc = { 'prettierd' },
        markdown = { 'prettierd' },
        python = { 'ruff_format' },
        rust = { 'rustfmt' },
        go = { 'goimports', 'gofmt', stop_after_first = true },
      },
      format_on_save = { timeout_ms = 1000, lsp_format = 'never' },
    },
  },
  {
    'nvim-telescope/telescope.nvim',
    cmd = 'Telescope',
    dependencies = { 'nvim-lua/plenary.nvim', 'nvim-tree/nvim-web-devicons' },
    opts = { defaults = { sorting_strategy = 'ascending', layout_config = { prompt_position = 'top' } } },
  },
  {
    'nvim-neo-tree/neo-tree.nvim',
    branch = 'v3.x',
    cmd = 'Neotree',
    dependencies = {
      'nvim-lua/plenary.nvim',
      'MunifTanjim/nui.nvim',
      'nvim-tree/nvim-web-devicons',
    },
    opts = {
      close_if_last_window = false,
      filesystem = {
        follow_current_file = { enabled = true },
        filtered_items = { visible = true },
        hijack_netrw_behavior = 'open_default',
      },
      window = { position = 'left', width = 32 },
    },
  },
  {
    'lewis6991/gitsigns.nvim',
    event = { 'BufReadPre', 'BufNewFile' },
    opts = {},
  },
  {
    'tpope/vim-fugitive',
    cmd = 'Git',
  },
  {
    'nvim-lualine/lualine.nvim',
    event = 'VeryLazy',
    dependencies = { 'nvim-tree/nvim-web-devicons', 'folke/tokyonight.nvim' },
    opts = { options = { theme = 'tokyonight', globalstatus = true } },
  },
  {
    'akinsho/bufferline.nvim',
    event = 'VeryLazy',
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    keys = {
      { '<leader>bn', '<cmd>BufferLineCycleNext<cr>', desc = 'Next buffer' },
      { '<leader>bp', '<cmd>BufferLineCyclePrev<cr>', desc = 'Previous buffer' },
      { '<leader>bd', '<cmd>bdelete<cr>', desc = 'Close buffer' },
    },
    opts = {
      options = {
        diagnostics = 'nvim_lsp',
        offsets = {
          { filetype = 'neo-tree', text = 'Explorer', highlight = 'Directory', text_align = 'left' },
        },
        separator_style = 'slant',
        show_close_icon = false,
      },
    },
  },
  {
    'folke/trouble.nvim',
    cmd = 'Trouble',
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    keys = {
      { '<leader>xx', '<cmd>Trouble diagnostics toggle<cr>', desc = 'Workspace diagnostics' },
      { '<leader>xX', '<cmd>Trouble diagnostics toggle filter.buf=0<cr>', desc = 'Buffer diagnostics' },
      { '<leader>cs', '<cmd>Trouble symbols toggle focus=false<cr>', desc = 'Document symbols' },
      { '<leader>cl', '<cmd>Trouble lsp toggle focus=false win.position=right<cr>', desc = 'LSP references and definitions' },
      { '<leader>xq', '<cmd>Trouble qflist toggle<cr>', desc = 'Quickfix list' },
    },
    opts = {},
  },
  {
    'mfussenegger/nvim-dap',
    dependencies = {
      'rcarriga/nvim-dap-ui',
      'nvim-neotest/nvim-nio',
      'leoluz/nvim-dap-go',
    },
    keys = {
      { '<F5>', function() require('dap').continue() end, desc = 'Debug: continue' },
      { '<F10>', function() require('dap').step_over() end, desc = 'Debug: step over' },
      { '<F11>', function() require('dap').step_into() end, desc = 'Debug: step into' },
      { '<F12>', function() require('dap').step_out() end, desc = 'Debug: step out' },
      { '<leader>db', function() require('dap').toggle_breakpoint() end, desc = 'Debug: toggle breakpoint' },
      { '<leader>dB', function() require('dap').set_breakpoint(vim.fn.input('Breakpoint condition: ')) end, desc = 'Debug: conditional breakpoint' },
      { '<leader>du', function() require('dapui').toggle() end, desc = 'Debug: toggle UI' },
      { '<leader>dr', function() require('dap').repl.toggle() end, desc = 'Debug: toggle REPL' },
      { '<leader>dt', function() require('dap-go').debug_test() end, ft = 'go', desc = 'Debug: nearest Go test' },
    },
    config = function()
      local dap = require('dap')
      local dapui = require('dapui')

      dapui.setup()
      dap.listeners.after.event_initialized['dapui_config'] = function() dapui.open() end
      dap.listeners.before.event_terminated['dapui_config'] = function() dapui.close() end
      dap.listeners.before.event_exited['dapui_config'] = function() dapui.close() end

      dap.adapters['pwa-node'] = {
        type = 'server',
        host = '127.0.0.1',
        port = '${port}',
        executable = { command = 'js-debug-adapter', args = { '${port}', '127.0.0.1' } },
      }
      local js_configurations = {
        {
          type = 'pwa-node',
          request = 'launch',
          name = 'Launch current file (Node.js)',
          program = '${file}',
          cwd = '${workspaceFolder}',
          sourceMaps = true,
          skipFiles = { '<node_internals>/**' },
        },
      }
      dap.configurations.javascript = js_configurations
      dap.configurations.javascriptreact = vim.deepcopy(js_configurations)
      dap.configurations.typescript = vim.deepcopy(js_configurations)
      dap.configurations.typescriptreact = vim.deepcopy(js_configurations)

      dap.adapters.python = { type = 'executable', command = 'debugpy-adapter', args = {} }
      dap.configurations.python = {
        {
          type = 'python',
          request = 'launch',
          name = 'Launch current file (Python)',
          program = '${file}',
          pythonPath = function()
            local project_python = vim.fn.getcwd() .. '/.venv/bin/python'
            if vim.fn.executable(project_python) == 1 then return project_python end
            return vim.fn.exepath('python3')
          end,
          console = 'integratedTerminal',
        },
      }

      dap.adapters.codelldb = {
        type = 'server',
        port = '${port}',
        executable = { command = 'codelldb', args = { '--port', '${port}' } },
      }
      dap.configurations.rust = {
        {
          type = 'codelldb',
          request = 'launch',
          name = 'Launch Rust executable',
          program = function()
            return vim.fn.input('Path to executable: ', vim.fn.getcwd() .. '/target/debug/', 'file')
          end,
          cwd = '${workspaceFolder}',
          stopOnEntry = false,
        },
      }

      require('dap-go').setup()
    end,
  },
  {
    'rcarriga/nvim-dap-ui',
    dependencies = { 'mfussenegger/nvim-dap', 'nvim-neotest/nvim-nio' },
  },
  {
    'nvim-neotest/nvim-nio',
    lazy = true,
  },
  {
    'leoluz/nvim-dap-go',
    dependencies = { 'mfussenegger/nvim-dap' },
  },
  {
    'folke/which-key.nvim',
    event = 'VeryLazy',
    opts = {},
  },
}
