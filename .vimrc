" 2012-04-23
" maksimr .vimrc
"
" curl https://raw.githubusercontent.com/kana/vim-version-manager/master/bin/vvm | python - setup
" source ~/.vvm/etc/login
" vvm update_itself
" brew install python@3.8
" CFLAGS="-I$HOME/.rvm/rubies/$RUBY_VERSION/include/$RUBY_VERSION" LDFLAGS="-L$HOME/.rvm/rubies/$RUBY_VERSION/lib/" vvm use vimorg--v8.2.2825 --install --with-features=huge --enable-rubyinterp --enable-pythoninterp=yes --with-python-config-dir=/usr/lib/python2.7/config --enable-python3interp=yes --with-python3-config-dir=$(python3.8-config --configdir)

set nocp                 " Turn off vi compatibility mode
set noeb                 " Turn off error bell
set novb                 " Turn off visual error bell
set mouse=a              " Enable mouse
set bs=2                 " Enable backspace
set nofixeol

set guifont=Terminus\ 14 " Set font (sudo apt-get install xfonts-terminus)
set t_Co=256             " Extended color support

set cursorline           " Highlight current line

set nu                   " Line number
set numberwidth=3        " Line number width

set lz
set guioptions=
set guioptions-=T
set guioptions-=r        " Remove right scrollbar

"set spell                " Включить проверку арфографии

set nowrap               " Не переносить длинные строки ( set wrap - переносить )
set textwidth=0

set scrolloff=5          " Минимальное количество строк остающихся выше/ниже курсора. Помогает не терять контекст.
set scrolljump=5         " Минимальное количество строк при скроле
set incsearch            " Поиск по ходу набора
set ignorecase           " Игнорирует регистр при поиске
set smartcase            " Переписывает ignorecase когда осуществляется поиск включающий заглавные буквы

set laststatus=2         " Включение строки состояния внизу редактора
set statusline=%<%f%h%m%r%{fugitive#statusline()}\ %b\ %{&encoding}\ 0x\ \ %l,%c%V\ %P " Формат строки состояния ( использует расширение git-fugitive )
set encoding=utf-8


set smartindent          " Умный автоматический отступ (ai - обычный автоматичексий отступ)
set smarttab             " При нажатии в начале строки TAB добавляет отступ равный shiftwidth
set et                   " Включить автозамену таба на пробелы
set shiftwidth=2         " Устоновить ширину сдвига >
set listchars=tab:\··     " Показываем табы в начале строки точками
set listchars+=trail:\␣   " Показываем пробел в конце строки как ␣
set list
set formatoptions-=o     " dont continue comments when pushing o/O

set backup " Создавать резервные копии файлов
set backupdir^=~/.vim/backup  " Создавать резервные копии файлов в папке sessions или если ее нет то в том же каталоге
set dir^=~/.vim/sessions " Складываем swp файлы в sessions папку, а не в текущую (:h swap-file)

set wildmode=list:longest,full " Автодополнение на манер zsh в командной строке
set wildmenu
set wildignore+=.hg,.git,.svn  " Version control
set wildignore+=*.DS_Store     " OSX bullshit
set wildignore+=*.pyc          " Python byte code

" Workaround for problem with watch in karma and webpack
" https://github.com/karma-runner/karma/issues/199
set backupcopy=yes

let g:LycosaExplorerSuppressPythonWarning = 1

" Not open error window when netrw
" can not create folder
let g:netrw_use_errorwindow    = 0

" ↪ Символ, который будет показан перед перенесенной строкой
let &showbreak = nr2char(8618).' '

" Конфигурация расширений
let g:netrw_list_hide='\~$,\~\*$,\.swp$,\.svn'

" устанавливаем <Leader>-клавишу и <LocalLeader>
let mapleader=','
let maplocalleader=mapleader

set suffixesadd +=.js

"For example, we could adapt the includeexpr option to
"allow Vim to directly open up the appropriate file when we
"press gf on a class name by converting
"CamelCase words to dash-case:
"http://arjanvandergaag.nl/blog/navigating-project-files-with-vim.html
set includeexpr=substitute(substitute(v:fname,'^.','\\l\\0',''),'\\(\\u\\l\\+\\\|\\l\\+\\)\\(\\u\\)','\\l\\1-\\l\\2','g')

syn on                     " Включаем синтаксис
filetype plugin indent on  " Для некоторых типов файлов настройки отступов были перенесены из plugin в indent. Поэтому не забываем включить его

set clipboard=unnamed " Копирование в сиситемный clipboard по нажатию на y(yank)

let data_dir = has('nvim') ? stdpath('data') . '/site' : '~/.vim'
if empty(glob(data_dir . '/autoload/plug.vim'))
  silent execute '!curl -fLo '.data_dir.'/autoload/plug.vim --create-dirs  https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'
  autocmd VimEnter * PlugInstall --sync | source $MYVIMRC
endif

call plug#begin()
  Plug 'sjl/gundo.vim'

  Plug 'preservim/nerdtree'
  nnoremap <leader>bb :NERDTreeFind<CR>
  nnoremap <leader>bt :NERDTreeToggle<CR>
  let g:NERDTreeHijackNetrw=0 " Don't open NERDTree when vim starts

  Plug 'thisivan/vim-bufexplorer'
  nnoremap <C-e> :Explore<cr>
  nnoremap <S-e> :BufExplorer<cr>

  Plug 'kana/vim-textobj-user'
  Plug 'glts/vim-textobj-comment'
  Plug 'junegunn/fzf', { 'do': { -> fzf#install() } }
  nnoremap <leader>, :FZF<cr>
  nnoremap <space>e :FZF<cr>

  Plug 'maksimr/Lucius2'

  Plug 'tpope/vim-fugitive'
  nnoremap <Leader>gs :Gstatus<CR>
  nnoremap <Leader>gd :Gdiff<CR>
  nnoremap <Leader>gc :Gcommit
  nnoremap <Leader>gb :Git blame<CR>
  nnoremap <Leader>gl :Glog<CR>
  nnoremap <Leader>gp :Git push<CR>

  command! -nargs=+ GitGrep execute 'let &grepprg="git grep --no-color" | silent grep! '.<q-args>.' | redraw! | set grepprg& | copen'
  nnoremap <Leader>gg :GitGrep <c-r>=expand("<cword>")<cr>

  Plug 'airblade/vim-gitgutter'
  let g:gitgutter_max_signs=5000

  Plug 'vim-scripts/The-NERD-Commenter'

  Plug 'Raimondi/delimitMate'
  let g:delimitMate_expand_cr = 1
  let g:delimitMate_expand_space = 1
  fun! NoAutoIndent()
    :DelimitMateSwitch
    setl noai nocin nosi inde=
  endfun
  command! NoAutoIndent call NoAutoIndent()

  Plug 'tpope/vim-eunuch'
  Plug 'tpope/vim-surround'
  Plug 'terryma/vim-multiple-cursors'

  Plug 'maksimr/vim-jsbeautify'
  Plug 'einars/js-beautify'
  augroup plugin_vim_jsbeautify
     autocmd!

     autocmd FileType html nnoremap <buffer> F :call HtmlBeautify()<cr>
     autocmd FileType css nnoremap <buffer> F :call CSSBeautify()<cr>
     autocmd FileType html vnoremap <buffer> F :call RangeHtmlBeautify()<cr>
     autocmd FileType css vnoremap <buffer> F :call RangeCSSBeautify()<cr>
  augroup END

  Plug 'neoclide/coc.nvim', {'commit': '3857588', 'do': ':CocInstall coc-json coc-tsserver coc-eslint coc-html coc-sh coc-vimlsp coc-docker'}
  let g:coc_default_semantic_highlight_groups = 1
  " brew install clojure-lsp/brew/clojure-lsp-native
  " Make <CR> auto-select the first completion item and notify coc.nvim to
  " format on enter, <cr> could be remapped by other vim plugin
  inoremap <silent><expr> <cr> coc#pum#visible() ? coc#_select_confirm()
                              \: "\<C-g>u\<CR>\<c-r>=coc#on_enter()\<CR>"
  inoremap <silent><expr> <tab> coc#pum#visible() ? coc#_select_confirm()
                              \: "\<C-g>u\<CR>\<c-r>=coc#on_enter()\<CR>"
  inoremap <expr><S-TAB> coc#pum#visible() ? "\<C-p>" : "\<C-h>"
  augroup coc_clojure
    autocmd!
    autocmd FileType clojure nnoremap <buffer> F :call CocActionAsync('format')<cr>
  augroup end
  augroup coc_javascript
    autocmd FileType javascript,typescript,typescriptreact,json nnoremap <buffer> F <Plug>(coc-format)
    autocmd FileType javascript,typescript,typescriptreact,json vnoremap <buffer> F <Plug>(coc-format-selected)
  augroup end
  nmap <silent> [g <Plug>(coc-diagnostic-prev)
  nmap <silent> ]g <Plug>(coc-diagnostic-next)
  nmap <silent> gd <Plug>(coc-definition)
  nmap <silent> gy <Plug>(coc-type-definition)
  nmap <silent> gi <Plug>(coc-implementation)
  nmap <silent> gr <Plug>(coc-references)
  nmap <leader>rn <Plug>(coc-rename)
  nmap <leader>ac  <Plug>(coc-codeaction)
  nmap <leader>.  <Plug>(coc-codeaction)
  nmap <leader>kl  <Plug>(coc-codelens-action)
  " Apply AutoFix to problem on the current line.
  nmap <leader>qf  <Plug>(coc-fix-current)
  nnoremap <silent><nowait> <C-p>  :<C-u>CocList -I symbols<cr>
  nnoremap <silent><nowait> <space>o  :<C-u>CocList outline<cr>
  " Use K to show documentation in preview window.
  nnoremap <silent> K :call <SID>show_documentation()<CR>
  function! s:show_documentation()
    if (index(['vim','help'], &filetype) >= 0)
      execute 'h '.expand('<cword>')
    elseif (coc#rpc#ready())
      call CocActionAsync('doHover')
    else
      execute '!' . &keywordprg . " " . expand('<cword>')
    endif
  endfunction
  " Highlight the symbol and its references when holding the cursor.
  set updatetime=300
  autocmd CursorHold * silent call CocActionAsync('highlight')
  " Map function and class text objects
  " NOTE: Requires 'textDocument.documentSymbol' support from the language server.
  xmap if <Plug>(coc-funcobj-i)
  omap if <Plug>(coc-funcobj-i)
  xmap af <Plug>(coc-funcobj-a)
  omap af <Plug>(coc-funcobj-a)
  " Add `:Format` command to format current buffer.
  command! -nargs=0 Format :call CocAction('format')

  Plug 'maksimr/vim-javascript'
  Plug 'rosstimson/bats.vim', { 'for': 'bat' }
  if has('nvim')
    let g:conjure#log#hud#border = "none"
    let g:conjure#log#hud#anchor = "SE"
    Plug 'Olical/conjure', {'for': 'clojure'}
    autocmd FileType clojure nnoremap <buffer> cpr :ConjureEvalBuf<cr>
    autocmd FileType clojure nnoremap <buffer> cpp :ConjureEvalCurrentForm<cr>
    autocmd FileType clojure nnoremap <buffer> cpP :ConjureEvalRootForm<cr>
  else
    Plug 'tpope/vim-fireplace', {'for': 'clojure'}
    augroup vim_fireplace
       autocmd!
       autocmd FileType clojure nnoremap <buffer> cpP :Eval<cr>
    augroup END
  endif
  Plug 'vim-scripts/paredit.vim', {'for': 'clojure'}
  Plug 'kana/vim-vspec'
  Plug 'tmhedberg/matchit'

  if !has('nvim')
    Plug 'editorconfig/editorconfig-vim'
    augroup vimrcgroup
        autocmd!
        autocmd BufEnter * silent EditorConfigReload
    augroup END
  endif

  Plug 'tpope/vim-projectionist'
  nnoremap <Leader>a :A<cr>

  if has('nvim')
    Plug 'github/copilot.vim'
    imap <silent> <C-]> <Plug>(copilot-next)
    imap <silent> <C-[> <Plug>(copilot-previous)
    let g:copilot_filetypes = { '*': v:false }
    let g:copilot_filetypes = { 'xml': v:false, 'dap-repl': v:false }
  endif

  if has('nvim')
    Plug 'mfussenegger/nvim-dap'
    autocmd FileType javascript,typescript nnoremap <buffer> \c <Cmd>lua require'dap'.terminate()<CR>
    autocmd FileType javascript,typescript nnoremap <buffer> \d <Cmd>lua require'dap'.continue()<CR>
    autocmd FileType javascript,typescript nnoremap <buffer> <leader>d\ <Cmd>lua require'dap'.continue()<CR>
    autocmd FileType javascript,typescript nnoremap <buffer> <leader>d' <Cmd>lua require'dap'.step_over()<CR>
    autocmd FileType javascript,typescript nnoremap <buffer> <leader>d; <Cmd>lua require'dap'.step_into()<CR>
    autocmd FileType javascript,typescript nnoremap <buffer> <leader>d: <Cmd>lua require'dap'.step_out()<CR>
    autocmd FileType javascript,typescript nnoremap <buffer> <leader>db <Cmd>lua require'dap'.toggle_breakpoint()<CR>
    autocmd FileType javascript,typescript nnoremap <buffer> <leader>b <Cmd>lua require'dap'.toggle_breakpoint()<CR>
    autocmd FileType javascript,typescript nnoremap <buffer> <leader>dr <Cmd>lua require'dap'.repl.open()<CR>
    nnoremap <silent> <F5> <Cmd>lua require'dap'.continue()<CR>
    nnoremap <silent> <F10> <Cmd>lua require'dap'.step_over()<CR>
    nnoremap <silent> <F11> <Cmd>lua require'dap'.step_into()<CR>
    nnoremap <silent> <F12> <Cmd>lua require'dap'.step_out()<CR>
    Plug 'microsoft/vscode-js-debug', {'do': 'npm ci --legacy-peer-deps && npx gulp dapDebugServer'}

    Plug 'rcarriga/nvim-dap-ui', { 'tag': 'v2.5.0' }
    nnoremap <leader>de <Cmd>lua require("dapui").eval()<CR>
  endif
call plug#end()


colorscheme lucius

" Если находимся внутри 'quickfix'
" тогда вызываем lclose иначе quit
function! QuitOrLclose(bang)
    if &buftype == 'quickfix'
        let g:syntastic_auto_loc_list = 0
        ccl
        lcl
        let g:syntastic_auto_loc_list = 1
    else
        if a:bang
            quit!
        else
            quit
        endif
    endif
endfunction
com! -nargs=? -bang Q call QuitOrLclose('!' == '<bang>')
cabbrev q Q

" return full path with the trailing slash
"  or an empty string if we're not in an npm project
fun! s:GetNodeModulesAbsPath ()
    let lcd_saved = fnameescape(getcwd())
    silent! exec "lcd" expand('%:p:h')
    let path = finddir('node_modules', '.;')
    exec "lcd" lcd_saved

    " fnamemodify will return full path with trailing slash;
    " if no node_modules found, we're safe
    return path is '' ? '' : fnamemodify(path, ':p')
endfun

fun! s:GetEslintExec (node_modules)
    if a:node_modules isnot ''
      let eslint_guess = a:node_modules is '' ? '' : a:node_modules . '.bin/eslint'
      return exepath(eslint_guess)
    endif
    return ''
endfun

fun! s:LetEslintExec (eslint_exec)
    if a:eslint_exec isnot ''
        let b:syntastic_javascript_eslint_exec = a:eslint_exec
    endif
endfun

fun! s:UpdateEslintExec ()
    let node_modules = s:GetNodeModulesAbsPath()
    let eslint_exec = s:GetEslintExec(node_modules)
    call s:LetEslintExec(eslint_exec)
endfun

" User project jshintrc if exist when run vim
function! s:find_jshintrc(dir)
    let l:found = globpath(a:dir, '.jshintrc')
    if filereadable(l:found)
        return l:found
    endif

    let l:parent = fnamemodify(a:dir, ':h')
    if l:parent != a:dir
        return s:find_jshintrc(l:parent)
    endif

    return "~/.jshintrc"
endfunction

function! UpdateJsHintConf()
    let l:dir = expand('%:p:h')
    let l:jshintrc = s:find_jshintrc(l:dir)

    if filereadable(l:jshintrc)
        let g:syntastic_javascript_jshint_args = '--config '.expand(l:jshintrc)
    endif
endfunction

let s:projectDir = fnameescape(getcwd())

fun! s:AddNodeModuleToPath ()
    let old_path = &path
    let node_modules = s:GetNodeModulesAbsPath()
    execute "set path=."
    execute "set path+=".s:projectDir
    execute "set path+=".node_modules
endfun

function! HasConfig(file, dir)
    return findfile(a:file, escape(a:dir, ' ') . ';') !=# ''
endfunction

augroup plugin_syntastic
    autocmd!
    autocmd BufEnter *.js call s:UpdateEslintExec()
    autocmd BufEnter *.js call s:AddNodeModuleToPath()
    autocmd BufNewFile,BufReadPre *.js  let b:syntastic_checkers = ['eslint']
augroup END


let g:slimv_swank_clojure = '!lein swank &'
let g:slimv_leader = '\'
let g:vimrcps_loaded = 1

autocmd BufNewFile,BufRead *.gradle setf groovy

nnoremap <c-w>> :resize +3<cr>
nnoremap <c-w>< :resize -3<cr>
nnoremap <c-w>" :belowright split %<cr>
nnoremap <s-f> mngg=G`n
nnoremap \ff :vim /\<<c-r>=expand("<cword>")<cr>\>/ **/*.
nnoremap \s :%s/\<<c-r>=expand("<cword>")<cr>\>/
nnoremap <esc>. :vertical res +10<cr>
nnoremap <esc>, :vertical res -10<cr>
nnoremap <leader>s g]
nnoremap <leader>ev :vsplit ~/.vimrc<cr>
nnoremap <leader>sv :so ~/.vimrc<cr>
nnoremap <leader>nt :tabnew %<cr>
nnoremap <leader>to :bel 8split<cr>:term<cr>i

inoremap jk <esc>
vnoremap <C-c> "+yy
onoremap in( :<c-u>normal! f(vi(<cr>
onoremap ip( :<c-u>normal! F)vi(<cr>
onoremap an( :<c-u>normal! f(va(<cr>
onoremap ap( :<c-u>normal! F)va(<cr>
cnoremap <C-r> <Up>
cnoremap <C-p> <Down>
cnoremap <Left> <Space><BS><Left>
cnoremap <Right> <Space><BS><Right>

augroup filetype_javascript
    autocmd!
    autocmd BufWritePre *.js silent exec "%s/\\s\\+$//e"
augroup END

augroup filetype_txt
    autocmd!
    autocmd FileType txt setlocal spell
augroup END

augroup filetype_vim
    autocmd!
    autocmd FileType vim setlocal foldmethod=marker
augroup END

match Error /\s\+$/

if filereadable(expand("~/.vimlocal"))
  so ~/.vimlocal
endif

if has('nvim')
lua <<EOF
  vim.api.nvim_set_hl(0, 'DapStopped', { ctermbg = 58, bg = Not })
  vim.fn.sign_define('DapBreakpoint', {text='○'})
  vim.fn.sign_define('DapStopped', {text='→', texthl='DapStopped', linehl='DapStopped', numhl='DapStopped'})

  local lvim_runtime_dir = os.getenv("NVIM_RUNTIME_DIR")
  if not lvim_runtime_dir then
    lvim_runtime_dir = vim.call("stdpath", "data")
  end

  local uv = vim.loop
  local path_sep = uv.os_uname().version:match("Windows") and "\\" or "/"
  local dap = require('dap')
  local debugger_path = table.concat({lvim_runtime_dir, "plugged", "vscode-js-debug", "dist", "src", "dapDebugServer.js"}, path_sep)

  dap.adapters["pwa-node"] = {
    type = "server",
    host = "localhost",
    port = "${port}",
    executable = {
      command = "node",
      args = {
        debugger_path,
        "${port}",
      }
    }
  }

  dap.configurations["javascript"] = {
   {
      type = "pwa-node",
      request = "launch",
      name = "Launch Program",
      program = "${file}",
      cwd = "${workspaceFolder}",
      resolveSourceMapLocations = {
        "${workspaceFolder}/**",
        "!**/node_modules/**"
      },
    }
  };

  dap.configurations["typescript"] = {
   {
      type = "pwa-node",
      request = "launch",
      name = "Launch Program",
      runtimeExecutable = "npx",
      runtimeArgs = { "tsx" },
      program = "${file}",
      cwd = "${workspaceFolder}",
      sourceMaps = true,
      resolveSourceMapLocations = { "${workspaceFolder}/dist/**/*.js", "${workspaceFolder}/**", "!**/node_modules/**" },
    }
  };

  local dapui = require("dapui");
  dapui.setup();
EOF
endif
