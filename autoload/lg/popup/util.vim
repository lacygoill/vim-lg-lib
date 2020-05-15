if exists('g:autoloaded_lg#popup#util')
    finish
endif
let g:autoloaded_lg#popup#util = 1

" TODO: When you'll need to log another feature (other than the popup window), move `#log()` in `autoload/lg.vim`.{{{
"
" You'll need to use a different expression for each feature; e.g.:
"
"     const s:DEBUG = {'popup': 0, 'other feature': 0}
"     const s:LOGFILE = {'popup-nvim': '/tmp/...', 'popup-vim': '/tmp/...', 'other-feature': '/tmp/...'}
"
"     ...
"                                  new argument
"                                  vvvvvvv
"     fu lg#log(msg, sfile, slnum, feature) abort
"         if !s:DEBUG[a:feature] | return | endif
"         ...
"         call writefile([time, source, a:msg], s:LOGFILE[a:feature], 'a')
"         ...
"}}}

" Init {{{1

const s:DEBUG = 0

if has('nvim')
    const s:LOGFILE = '/tmp/.nvim-floating-window.log.vim'
else
    const s:LOGFILE = '/tmp/.vim-popup-window.log.vim'
endif

" Functions {{{1
fu lg#popup#util#get_borderchars() abort "{{{2
    return ['─', '│', '─', '│', '┌', '┐', '┘', '└']
endfu

fu lg#popup#util#set_borderchars(opts) abort "{{{2
    call extend(a:opts, #{borderchars: lg#popup#util#get_borderchars()}, 'keep')
endfu

fu lg#popup#util#is_terminal_buffer(n) abort "{{{2
    return type(a:n) == v:t_number && a:n > 0 && getbufvar(a:n, '&bt', '') is# 'terminal'
endfu

fu lg#popup#util#get_lines(what) abort "{{{2
    if type(a:what) == v:t_list
        let lines = a:what
    elseif type(a:what) == v:t_string
        let lines = split(a:what, '\n')
    elseif type(a:what) == v:t_number
        let lines = getbufline(a:what, 1, '$')
    endif
    return lines
endfu

fu lg#popup#util#get_notification_opts(lines) abort "{{{2
    let longest = s:get_longest_width(a:lines)
    let [width, height] = [longest, len(a:lines)]
    let [row, col] = [2, &columns]
    let opts = {
        \ 'row': row,
        \ 'col': col,
        \ 'width': width,
        \ 'height': height,
        \ 'border': [],
        "\ only needed in Nvim (Vim highlights the border with 'highlight' if 'borderhighlight' is not specified)
        \ 'borderhighlight': 'WarningMsg',
        \ 'highlight': 'WarningMsg',
        \ 'focusable': v:false,
        \ 'pos': 'topright',
        \ 'time': 3000,
        \ }
    if !has('nvim')
        call extend(opts, #{
            \ tabpage: -1,
            \ zindex: 300,
            \ })
    endif
    return opts
endfu

fu s:get_longest_width(lines) abort
    return max(map(copy(a:lines), {_,v -> strchars(v, 1)}))
endfu

fu lg#popup#util#log(msg, sfile, slnum) abort "{{{2
    if !s:DEBUG | return | endif
    let time = '" '..strftime('%H:%M:%S')
    let funcname = matchstr(a:sfile, '.*\.\.\zs.*')
    let sourcefile = split(execute('verb fu '..funcname), '\n')[1]
    let [sourcefile, lnum] = matchlist(sourcefile, '^\s*Last set from \(.*\)\s\+line \(\d\+\)')[1:2]
    let source = '" '..sourcefile..':'..(lnum + a:slnum)
    call writefile([time, source, a:msg], s:LOGFILE, 'a')
endfu

