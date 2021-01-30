" ***************************************************************************************
" * Install vim-plug if not found
" ***************************************************************************************
let autoload_plug_path = stdpath('data') . '/site/autoload/plug.vim'
if !filereadable(autoload_plug_path)
  silent execute '!curl -fLo ' . autoload_plug_path . '  --create-dirs 
      \ "https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim"'
  autocmd VimEnter * PlugInstall --sync | source $MYVIMRC
endif
unlet autoload_plug_path

" Run PlugInstall if there are missing plugins
autocmd VimEnter * if len(filter(values(g:plugs), '!isdirectory(v:val.dir)'))
  \| PlugInstall --sync | source $MYVIMRC
\| endif
" ***************************************************************************************


" ***************************************************************************************
" * Vim Config
" ***************************************************************************************
set guifont=DroidSansMono_Nerd_Font:h11 " needed?
set number
set showcmd
set cursorline
" ***************************************************************************************


" ***************************************************************************************
" * Fix Healthcheck
" ***************************************************************************************
" To disable Python 2 support
let g:loaded_python_provider = 0
" To configure path to python 3
let g:python3_host_prog = "/usr/local/bin/python3"
" ***************************************************************************************


" ***************************************************************************************
" * Manage plugin
" ***************************************************************************************
call plug#begin()

" *************************************************************************
" * NERDTree : File Explorer
" ** URL: https://github.com/preservim/nerdtree
" *************************************************************************
Plug 'preservim/nerdtree'
Plug 'Xuyuanp/nerdtree-git-plugin'
Plug 'tiagofumo/vim-nerdtree-syntax-highlight'
" *************************************************************************
" ** Start NERDTree when Vim is started without file arguments.
autocmd StdinReadPre * let s:std_in=1
autocmd VimEnter * if argc() == 0 && !exists('s:std_in') | NERDTree | endif
" ** Exit Vim if NERDTree is the only window left.
autocmd BufEnter * if tabpagenr('$') == 1 && winnr('$') == 1 && exists('b:NERDTree') && b:NERDTree.isTabTree() | quit | endif
" ** Open the existing NERDTree on each new tab.
autocmd BufWinEnter * silent NERDTreeMirror
" *************************************************************************


" *************************************************************************
" * Deoplete : Code Completion
" ** URL: https://github.com/Shougo/deoplete.nvim
" *************************************************************************
if has('nvim')
  Plug 'Shougo/deoplete.nvim', { 'do': ':UpdateRemotePlugins' }
else
  Plug 'Shougo/deoplete.nvim'
  Plug 'roxma/nvim-yarp'
  Plug 'roxma/vim-hug-neovim-rpc'
endif
Plug 'carlitux/deoplete-ternjs', { 'do': 'npm install -g tern' } " for javascript
" *************************************************************************
let g:deoplete#enable_at_startup = 1
" *************************************************************************


" *************************************************************************
" * Vim-javascript - Synthax hightlight
" ** URL: https://vimawesome.com/plugin/vim-javascript
Plug 'pangloss/vim-javascript'
" *************************************************************************


" *************************************************************************
" CtrlP: Recherche avancée
" ** URL: https://vimawesome.com/plugin/ctrlp-vim-everything-has-changed
" *************************************************************************
Plug 'ctrlpvim/ctrlp.vim'
" *************************************************************************
set wildignore+=*/tmp/*,*.so,*.swp,*.zip     " MacOSX/Linux
let g:ctrlp_custom_ignore = 'node_modules\|DS_Store\|git'
let g:ctrlp_user_command = ['.git', 'cd %s && git ls-files -co --exclude-standard'] " ignore file in .gitignore
" *************************************************************************


" *************************************************************************
" * Fugitive.vim - Git tools
" ** URL: https://vimawesome.com/plugin/fugitive-vim
" *************************************************************************
Plug 'tpope/vim-fugitive'
" *************************************************************************


" *************************************************************************
" Vim-Airline: Theme VIM
" ** URL: https://vimawesome.com/plugin/vim-airline-superman
" *************************************************************************
Plug 'vim-airline/vim-airline'
Plug 'vim-airline/vim-airline-themes'
" *************************************************************************
let g:airline_theme='luna' " https://github.com/vim-airline/vim-airline/wiki/Screenshots
let g:airline#extensions#tabline#enabled = 1 " Smarter tab line "used when there is no other tab. needed ?
let g:airline#extensions#tabline#left_sep = ' '
let g:airline#extensions#tabline#left_alt_sep = '|'
" Tab formatter: default | jsformatter | unique_tail | unique_tail_improved
let g:airline#extensions#tabline#formatter = 'default'
" *************************************************************************


" *************************************************************************
" vim-devicons Always load the vim-devicons as the very last one.
" *************************************************************************
Plug 'ryanoasis/vim-devicons'
" *************************************************************************

call plug#end()
" ***************************************************************************************


" ***************************************************************************************
" * Specific call required
" ***************************************************************************************
call deoplete#custom#option('num_processes', 4) " to fix an issue with nvim, deoplite and python
" ***************************************************************************************


" ***************************************************************************************
" * Map command
" ***************************************************************************************
" switch on tabs
map <S-Right>      :tabn<CR>
map <S-Left>       :tabp<CR>
map <leader>t      :tabnew<CR>

"To resize split
nnoremap <C-Right> <C-W>>
nnoremap <C-Left> <C-W><
nnoremap <C-Down>  :exe "resize " . (winheight(0) * 3/2)<CR>
nnoremap <C-Up>  :exe "resize " . (winheight(0) * 2/3)<CR>

"Move between splits   
nnoremap <C-J> <C-W><C-J>
nnoremap <C-K> <C-W><C-K>
nnoremap <C-L> <C-W><C-L>
nnoremap <C-H> <C-W><C-H>

"Move between tabs 
map <C-t><up> :tabr<cr>
map <C-t><down> :tabl<cr>
map <C-t><left> :tabp<cr>
map <C-t><right> :tabn<cr>

"Buffer maps
nnoremap <C-n> :bnext<CR>
nnoremap <C-p> :bprevious<CR>


" NERDTree
map <C-n>          :NERDTreeToggle<CR>
map <leader>n      :NERDTreeFocus<CR>

" CtrlP
map <leader>f :CtrlP<CR>
" ***************************************************************************************
