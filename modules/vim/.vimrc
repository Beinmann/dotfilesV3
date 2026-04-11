" =========================
"  Minimal Quality-of-Life Vim config
" =========================

" Disabled (optional) settings at the bottom

" --- General ---
set nocompatible
set encoding=utf-8
set fileencoding=utf-8
set number
set relativenumber
set hidden
set showcmd
set ruler
set scrolloff=5
set laststatus=2
set signcolumn=yes
set title
set showmatch          " Briefly jump to matching bracket when inserting one
set visualbell         " Flash instead of beep
set linebreak          " Wrap long lines at word boundaries
set notitle

" --- Undofile ---
set undofile
set undodir=~/Main/Data/vim/undo

" --- Indentation ---
set tabstop=4
set shiftwidth=4
set expandtab
set smartindent
set autoindent

" --- Search ---
set ignorecase
set smartcase
set hlsearch
set incsearch

" --- Visuals ---
syntax on
set termguicolors
" set background=dark
" colorscheme slate
set noshowmode         " Hide --INSERT-- if you plan to use a statusline plugin

" --- Split behavior ---
set splitbelow
set splitright

" --- Backup/Swap ---
set nobackup
set nowritebackup
set noswapfile

" --- QoL ---
set clipboard=unnamedplus
set mouse=a
set wildmenu
set wildmode=list:longest
set updatetime=300

" --- Remaps ---
" Map leader to space
let mapleader=" "

" --- Optional: Plugin section (commented) ---
" call plug#begin('~/.vim/plugged')
" Plug 'tpope/vim-sensible'
" Plug 'vim-airline/vim-airline'
" Plug 'tpope/vim-commentary'
" Plug 'jiangmiao/auto-pairs'
" call plug#end()



" --- Settings that are disabled for now but that I might use in the future ---

" set cursorline
" set completeopt=menuone,noinsert,noselect
" Easier window navigation
" nnoremap <C-h> <C-w>h
" nnoremap <C-j> <C-w>j
" nnoremap <C-k> <C-w>k
" nnoremap <C-l> <C-w>l
" Quickly clear search highlight
" nnoremap <leader>/ :nohlsearch<CR>
" Yank to end of line (like D)
" nnoremap Y y$
" set colorcolumn=80     " Highlight column 80 as a text width guide
