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
	set guifont=DroidSansMono_Nerd_Font:h11 			" needed?
	set number 											" display number line
	set showcmd
	set cursorline 										" underline active line
	set tabstop=2
	set shiftwidth=2
	" set expandtab 										" replace tab by 2 spaces
	set list
	set listchars=eol:⏎,tab:\ \ ┊,trail:●,extends:…,precedes:…,space:·
	set mouse=a
" ***************************************************************************************


" ***************************************************************************************
" * Fix Healthcheck
" ***************************************************************************************
	let g:loaded_python_provider = 0 					" To disable Python 2 support
	if has("macunix")
		let g:python3_host_prog = "/usr/local/bin/python3" 	" To configure path to python 3
	endif
	if has("unix")
		let g:python3_host_prog = "/usr/bin/python3"
	endif
" ***************************************************************************************


" ***************************************************************************************
" * Manage plugin
" *************************************************************************
	call plug#begin()
" ***************************************************************************************
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
	" autocmd BufEnter * if tabpagenr('$') == 1 && winnr('$') == 1 && exists('b:NERDTree') && b:NERDTree.isTabTree() | quit | endif
	" ** Open the existing NERDTree on each new tab.
	" autocmd BufWinEnter * silent NERDTreeMirror
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
	if has("macunix")
		Plug 'carlitux/deoplete-ternjs', { 'do': 'npm install -g tern' } " for javascript
	else
		Plug 'carlitux/deoplete-ternjs', { 'do': 'sudo npm install -g tern' } " for javascript
	endif
" *************************************************************************
	let g:deoplete#enable_at_startup = 1
" *************************************************************************

" *************************************************************************
" * Vim-javascript - Synthax hightlight
" ** URL: https://vimawesome.com/plugin/vim-javascript
" *************************************************************************
	Plug 'pangloss/vim-javascript'
" *************************************************************************

" *************************************************************************
" * palenight.vim - colorscheme
" ** URL: https://github.com/drewtempelmeyer/palenight.vim
" *************************************************************************
	Plug 'drewtempelmeyer/palenight.vim'
" *************************************************************************

" *************************************************************************
" * CtrlP: Recherche avancée
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
" * Vim-gitgutter - highlight git changes
" ** URL: https://vimawesome.com/plugin/vim-gitgutter
" *************************************************************************
	Plug 'airblade/vim-gitgutter'
" *************************************************************************
	let g:gitgutter_enabled = 1
	let g:gitgutter_highlight_lines = 1
	let g:gitgutter_signs = 1
	let g:gitgutter_highlight_linenrs = 1
	let g:gitgutter_async = 1
	let g:gitgutter_preview_win_floating = 1
" *************************************************************************

" *************************************************************************
" * Vim-Airline - Theme VIM
" ** URL: https://vimawesome.com/plugin/vim-airline-superman
" *************************************************************************
	Plug 'vim-airline/vim-airline'
	Plug 'vim-airline/vim-airline-themes'
" *************************************************************************
	let g:airline_theme='luna' " https://github.com/vim-airline/vim-airline/wiki/Screenshots
	let g:airline#extensions#tabline#enabled = 1 " Smarter tab line "used when there is no other tab. needed ?
	let g:airline#extensions#tabline#left_sep = ' '
	let g:airline#extensions#tabline#left_alt_sep = '|'
	let g:airline#extensions#tabline#formatter = 'default' " Tab formatter: default | jsformatter | unique_tail | unique_tail_improved
" *************************************************************************

" *************************************************************************
" * Syntastic - Syntax checking hacks for vim
" ** URL: https://vimawesome.com/plugin/syntastic
" *************************************************************************
	Plug 'scrooloose/syntastic'
" *************************************************************************
	set statusline+=%#warningmsg#
	set statusline+=%{SyntasticStatuslineFlag()}
	set statusline+=%*

	let g:syntastic_always_populate_loc_list = 1
	let g:syntastic_auto_loc_list = 1
	let g:syntastic_check_on_open = 1
	let g:syntastic_check_on_wq = 0
" *************************************************************************

" *************************************************************************
" vim-devicons Always load the vim-devicons as the very last one.
" *************************************************************************
	Plug 'ryanoasis/vim-devicons'
" ***************************************************************************************
	call plug#end()
" ***************************************************************************************


" ***************************************************************************************
" * Specific call required
" ***************************************************************************************
	call deoplete#custom#option('num_processes', 4) " to fix an issue with nvim, deoplite and python
" ***************************************************************************************


" ***************************************************************************************
" * Map command
" ******************************************************************************
" Navigate ********************************************************
	map <leader>t      :tabnew<CR>
	" *** Switch on tabs **********************************************
	map <S-Right>      :tabn<CR>
	map <S-Left>       :tabp<CR>
	" *** Switch on Buffer maps ***************************************
	nnoremap <S-Up> :bnext<CR>
	nnoremap <S-Down> :bprevious<CR>
	" *** To split screen *********************************************
	" <C-W>V Horizontal Split
	" <C-W>S Vertical Split
	" *** To resize split *********************************************
	nnoremap <silent> <C-S-Right> :exe "vertical resize " . (winwidth(0) * 5/4)<CR>
	nnoremap <silent> <C-S-Left> :exe  "vertical resize " . (winwidth(0) * 4/5)<CR>
	nnoremap <silent> <C-S-Down> :exe "resize " . (winheight(0) * 5/4)<CR>
	nnoremap <silent> <C-S-Up> :exe "resize " . (winheight(0) * 4/5)<CR>
	" *** Move between splits *****************************************
	nnoremap <C-J> <C-W><C-J>
	nnoremap <C-K> <C-W><C-K>
	nnoremap <C-L> <C-W><C-L>
	nnoremap <C-H> <C-W><C-H>
" ******************************************************************************
" *** NERDTree ****************************************************
	map <C-n>          :NERDTreeToggle<CR>
	map <leader>n      :NERDTreeFocus<CR>
" ******************************************************************************
" *** CtrlP *******************************************************
	map <leader>f :CtrlP<CR>
" ******************************************************************************
" ***************************************************************************************


" ***************************************************************************************
" Fix for accidental Ctrl+U: https://vim.fandom.com/wiki/Recover_from_accidental_Ctrl-U
	inoremap <c-u> <c-g>u<c-u>
	inoremap <c-w> <c-g>u<c-w>
" ***************************************************************************************


" ***************************************************************************************
" * Define theme
" ***************************************************************************************
	set termguicolors     " enable true colors support
	set background=dark
	colorscheme palenight
	let g:lightline = { 'colorscheme': 'palenight' }
	let g:airline_theme = "palenight"
" ***************************************************************************************
