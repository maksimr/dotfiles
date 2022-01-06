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

set guifont=Terminus\ 14 " Set font (sudo apt-get install xfonts-terminus)
set t_Co=256             " Extended color support

set cursorline           " Highlight current line

set nu                   " Line number
set numberwidth=3        " Line number width

set lz
set guioptions=a
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

if system('uname -s') == "Darwin\n"
  set clipboard=unnamed " Копирование в сиситемный clipboard по нажатию на y(yank)
endif

let data_dir = has('nvim') ? stdpath('data') . '/site' : '~/.vim'
if empty(glob(data_dir . '/autoload/plug.vim'))
  silent execute '!curl -fLo '.data_dir.'/autoload/plug.vim --create-dirs  https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'
  autocmd VimEnter * PlugInstall --sync | source $MYVIMRC
endif

call plug#begin()
  Plug 'wincent/Command-T', { 'do': 'cd ruby/command-t/ext/command-t && { make clean; ruby extconf.rb && make }' }
  nnoremap <leader>, :CommandT<cr>
  let g:CommandTFileScanner="git"

  Plug 'kshenoy/vim-signature'
  Plug 'sjl/gundo.vim'

  Plug 'thisivan/vim-bufexplorer'
  nnoremap <C-e> :Explore<cr>
  nnoremap <S-e> :BufExplorer<cr>

  Plug 'Lokaltog/vim-easymotion'
  let g:EasyMotion_leader_key = "<space>"

  Plug 'kana/vim-textobj-user'
  Plug 'glts/vim-textobj-comment'
  Plug 'junegunn/fzf'

  Plug 'Lokaltog/vim-powerline'
  set encoding=utf-8

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

     autocmd FileType javascript nnoremap <buffer>  <c-f> :call JsxBeautify()<cr>
     autocmd BufEnter *.jsx nnoremap <buffer>  <c-f> :call JsxBeautify()<cr>
     autocmd BufEnter *.json nnoremap <buffer>  <c-f> :call JsonBeautify()<cr>
     autocmd FileType html nnoremap <buffer> <c-f> :call HtmlBeautify()<cr>
     autocmd FileType css nnoremap <buffer> <c-f> :call CSSBeautify()<cr>

     autocmd FileType javascript vnoremap <buffer>  <c-f> :call RangeJsBeautify()<cr>
     autocmd BufEnter *.jsx vnoremap <buffer>  <c-f> :call RangeJsxBeautify()<cr>
     autocmd BufEnter *.json vnoremap <buffer>  <c-f> :call RangeJsonBeautify()<cr>
     autocmd FileType html vnoremap <buffer> <c-f> :call RangeHtmlBeautify()<cr>
     autocmd FileType css vnoremap <buffer> <c-f> :call RangeCSSBeautify()<cr>
  augroup END

  Plug 'metakirby5/codi.vim'

  Plug 'neoclide/coc.nvim', {'branch': 'release', 'do': ':CocInstall coc-json coc-tsserver'}
  " Make <CR> auto-select the first completion item and notify coc.nvim to
  " format on enter, <cr> could be remapped by other vim plugin
  inoremap <silent><expr> <cr> pumvisible() ? coc#_select_confirm()
                              \: "\<C-g>u\<CR>\<c-r>=coc#on_enter()\<CR>"
  " Use tab for trigger completion with characters ahead and navigate
  inoremap <silent><expr> <TAB>
        \ pumvisible() ? "\<C-n>" :
        \ <SID>check_back_space() ? "\<TAB>" :
        \ coc#refresh()
  inoremap <expr><S-TAB> pumvisible() ? "\<C-p>" : "\<C-h>"
  function! s:check_back_space() abort
    let col = col('.') - 1
    return !col || getline('.')[col - 1]  =~# '\s'
  endfunction
  nmap <silent> [g <Plug>(coc-diagnostic-prev)
  nmap <silent> ]g <Plug>(coc-diagnostic-next)
  nmap <silent> gd <Plug>(coc-definition)
  nmap <silent> gy <Plug>(coc-type-definition)
  nmap <silent> gi <Plug>(coc-implementation)
  nmap <silent> gr <Plug>(coc-references)
  nmap <leader>rn <Plug>(coc-rename)
  nmap <leader>ac  <Plug>(coc-codeaction)
  nmap <leader>kl  <Plug>(coc-codelens-action)
  nnoremap <silent><nowait> <C-p>  :<C-u>CocList -I symbols<cr>
  nnoremap <silent><nowait> <space>o  :<C-u>CocList outline<cr>

  Plug 'maksimr/vim-javascript'
  Plug 'rosstimson/bats.vim', { 'for': 'bat' }
  Plug 'guns/vim-clojure-static', {'for': 'clojure'}
  Plug 'tpope/vim-fireplace', {'for': 'clojure'}
  Plug 'kovisoft/slimv', {'for': 'clojure'}
  Plug 'vim-scripts/paredit.vim', {'for': 'clojure'}
  Plug 'kana/vim-vspec'
  Plug 'tmhedberg/matchit'

  Plug 'editorconfig/editorconfig-vim'
  augroup vimrcgroup
      autocmd!
      autocmd BufEnter * silent EditorConfigReload
  augroup END

  Plug 'mhinz/vim-startify'
  Plug 'udalov/kotlin-vim'
  Plug 'tpope/vim-projectionist'
  nnoremap <Leader>a :A<cr>
call plug#end()


colorscheme lucius

" <esc> - Alt
let c='l'

while c <= 'z'
    exec "set <A-".c.">=\e".c
    exec "inoremap \e".c." <A-".c.">"
    let c = nr2char(1+char2nr(c))
endw

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
    let eslint_guess = a:node_modules is '' ? '' : a:node_modules . '.bin/eslint'
    return exepath(eslint_guess)
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

nnoremap <c-w>" :belowright split %<cr>
nnoremap <s-f> mngg=G`n
nnoremap \ff :vim /\<<c-r>=expand("<cword>")<cr>\>/ **/*.
nnoremap \s :%s/\<<c-r>=expand("<cword>")<cr>\>/
nnoremap <esc>. :vertical res +10<cr>
nnoremap <esc>, :vertical res -10<cr>
nnoremap <leader>s g]
nnoremap <leader>o <C-]>
nnoremap <leader>ev :vsplit ~/.vimrc<cr>
nnoremap <leader>sv :so ~/.vimrc<cr>
nnoremap <leader>nt :tabnew %<cr>

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
