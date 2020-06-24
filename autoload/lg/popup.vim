if exists('g:autoloaded_lg#popup')
    finish
endif
let g:autoloaded_lg#popup = 1

" `#create()` raises errors!{{{
"
" Don't use `minwidth`, `maxwidth`, `minheight`, `maxheight`.
" Just use `width` and `height`.
"}}}
" I have another issue with one of these functions!{{{
"
" Switch `s:DEBUG` to 1 in this file.
" Reproduce your issue, then read the logfile.
"
" Check whether the code in the logfile looks ok.
" If it does, the issue may be due to a Vim bug.
" Otherwise, if  some line seems wrong,  check out your source  code; start your
" search by pressing `C-w F` on the previous commented line.
"}}}

" TODO: When you'll need to log another feature (other than the popup window), move `s:log()` in `autoload/lg.vim`.{{{
"
" You'll need to use a different expression for each feature; e.g.:
"
"     const s:DEBUG = {'popup': 0, 'other feature': 0}
"     const s:LOGFILE = {'popup-nvim': '/tmp/...', 'popup-vim': '/tmp/...', 'other-feature': '/tmp/...'}
"
"     ...
"                                  new argument
"                                  v-----v
"     fu lg#log(msg, sfile, slnum, feature) abort
"         if !s:DEBUG[a:feature] | return | endif
"         ...
"         call writefile([time, source, a:msg], s:LOGFILE[a:feature], 'a')
"         ...
"}}}

" Init {{{1

const s:DEBUG = 0
const s:LOGFILE = '/tmp/.vim-popup-window.log.vim'

" Interface {{{1
fu lg#popup#create(what, opts) abort "{{{2
    let [what, opts] = [a:what, a:opts]
    let has_border = has_key(opts, 'border')
    let is_term = has_key(opts, 'term') ? remove(opts, 'term') : v:false
    if !has_border && !is_term
        return s:basic(what, opts)
    elseif has_border && !is_term
        return s:border(what, opts)
    elseif is_term
        return s:terminal(what, opts)
    endif
endfu

fu lg#popup#notification(what, ...) abort "{{{2
    let [what, opts] = [a:what, a:0 ? a:1 : {}]
    let lines = s:get_lines(what)
    let n_opts = s:get_notification_opts(lines)
    call extend(opts, n_opts, 'keep')
    call lg#popup#create(lines, opts)
endfu
"}}}1
" Core {{{1
fu s:basic(what, opts) abort "{{{2
    let [what, opts, sfile] = [a:what, a:opts, expand('<sfile>')]
    if type(what) == v:t_string && what =~# '\n'
        let what = split(what, '\n')
    endif
    call extend(opts, #{zindex: s:get_zindex()}, 'keep')

    " Vim doesn't recognize the 'width' and 'height' keys.
    " We really need the `max` keys.{{{
    "
    " For  example,  without the  `maxheight`  key,  the window's  height  would
    " increase when executing a shell command with a long output (e.g. `$ infocmp -1x`).
    "
    " Note that if the function uses `border: []`, then we don't need the `max` keys.
    " However, there's  no guarantee that the  function will use a  border; e.g.
    " `border` could have been set with the value `[0,0,0,0]`.
    "
    " Besides, we set  the `max` keys to be consistent  with popup windows where
    " we don't use a border.
    "}}}
    call extend(opts, #{
        \ minwidth: opts.width,
        \ maxwidth: opts.width,
        \ minheight: opts.height,
        \ maxheight: opts.height,
        \ })
    call remove(opts, 'width') | call remove(opts, 'height')
    let cmd = printf('let winid = popup_create(%s, %s)', what, opts)
    call s:log(cmd, sfile, expand('<slnum>'))
    exe cmd

    " Don't reset the topline of the popup on the next screen redraw.{{{
    "
    " Useful when you've installed key bindings to scroll in the popup and don't
    " want Vim to cancel your scrolling on the next redraw.
    "
    " The value `0` is documented at `:h popup_create-arguments /firstline`:
    "
    " >     firstline       ...
    " >                     Set to zero to leave the position as set by commands.
    "}}}
    let cmd = printf('call popup_setoptions(%d, #{firstline: 0})', winid)
    call s:log(cmd, sfile, expand('<slnum>'))
    exe cmd
    return [winbufnr(winid), winid]
endfu

fu s:border(what, opts) abort "{{{2
    let [what, opts] = [a:what, a:opts]

    " reset geometry so that the inner text fits inside the border
    " Why these particular numbers in the padding list?{{{
    "
    " I like to add  one empty column between the start/end of  the text and the
    " left/right borders.  It's more aesthetically pleasing.
    "
    " OTOH, I  don't like adding an  empty line above/below the  text.  It takes
    " too much space, which is more precious vertically than horizontally.
    "}}}
    call extend(opts, #{padding: [0,1,0,1]}, 'keep')
    call extend(opts, #{
        "\ to get the same position as in Nvim
        \ col: opts.col - 1,
        \ width: opts.width,
        \ height: opts.height,
        \ })
    " Vim expects the 'borderhighlight' key to be a list.  We want a string; do the conversion.
    call extend(opts, #{borderhighlight: [get(opts, 'borderhighlight', '')]})

    " open final window
    call s:set_borderchars(opts)
    return s:basic(what, opts)
endfu

fu s:terminal(what, opts) abort "{{{2
    let [what, opts, sfile] = [a:what, a:opts, expand('<sfile>')]
    " If `what` is the number of a terminal buffer, don't create yet another one.{{{
    "
    " Just use `what`.
    " This is useful, in particular, when toggling a popup terminal.
    "}}}
    if s:is_terminal_buffer(what)
        let bufnr = what
    else
        " Why `VIM_POPUP_TERMINAL`?{{{
        "
        " Some shell script/function may need to  know whether it's running in a
        " Vim popup, because it may want to make Vim to do sth which is forbidden.
        " Right now, we inspect this variable in `~/bin/drop`.
        "}}}
        let cmd = 'let bufnr = term_start(&shell, #{hidden: v:true, term_finish: ''close'','
            \ ..' term_kill: ''hup'', env: #{VIM_POPUP_TERMINAL: 1}})'
        call s:log(cmd, sfile, expand('<slnum>'))
        exe cmd
    endif
    " in Terminal-Normal mode, don't highlight empty cells with `Pmenu` (same thing for padding cells)
    call extend(opts, #{highlight: 'Normal'})
    " make sure a border is drawn even if the `border` key was not set
    call extend(opts, #{border: get(opts, 'border', [])})
    let info = s:border(bufnr, opts)
    call s:fire_terminal_events()
    return info
endfu
"}}}1
" Util {{{1
fu s:fire_terminal_events() abort "{{{2
    " Install our custom terminal settings as soon as the terminal buffer is displayed in a window.{{{
    "
    " Useful, for example,  to get our `Esc Esc` key  binding, and for `M-p`
    " to work (i.e. recall latest command starting with current prefix).
    "}}}
    if exists('#TerminalWinOpen') | do <nomodeline> TerminalWinOpen | endif
    if exists('#User#TermEnter') | do <nomodeline> User TermEnter | endif
endfu

fu s:get_zindex() abort "{{{2
    " Issue:{{{
    "
    " When  we  open  a popup,  we  want  it  to  be visible  immediately  (i.e.
    " not  hidden  by another  popup  with  a higher  `zindex`),  so  we need  a
    " not-too-small `zindex` value.
    "
    " But when Vim or a third-party plugin opens  a popup, we also want it to be
    " visible immediately, so we need a not-too-big `zindex` value.
    "}}}
    " Solution:{{{
    "
    " Get  the `zindex`  value of  the popup  at the  screen position  where the
    " cursor is currently.  Add `1` to that, and return this value.
    "}}}
    let screenpos = screenpos(win_getid(), line('.'), col('.'))
    let opts = popup_locate(screenpos.row, screenpos.col)->popup_getoptions()
    return get(opts, 'zindex', 0) + 1
endfu

fu s:get_borderchars() abort "{{{2
    return ['─', '│', '─', '│', '┌', '┐', '┘', '└']
endfu

fu s:set_borderchars(opts) abort "{{{2
    call extend(a:opts, #{borderchars: s:get_borderchars()}, 'keep')
endfu

fu s:get_lines(what) abort "{{{2
    if type(a:what) == v:t_list
        let lines = a:what
    elseif type(a:what) == v:t_string
        let lines = split(a:what, '\n')
    elseif type(a:what) == v:t_number
        let lines = getbufline(a:what, 1, '$')
    endif
    return lines
endfu

fu s:get_notification_opts(lines) abort "{{{2
    let longest = s:get_longest_width(a:lines)
    let [width, height] = [longest, len(a:lines)]
    let opts = #{
        \ line: 2,
        \ col: &columns,
        \ width: width,
        \ height: height,
        \ border: [],
        \ highlight: 'WarningMsg',
        \ focusable: v:false,
        \ pos: 'topright',
        \ time: 3000,
        \ tabpage: -1,
        \ zindex: 300,
        \ }
    return opts
endfu

fu s:get_longest_width(lines) abort
    return max(map(copy(a:lines), {_,v -> strchars(v, 1)}))
endfu

fu s:is_terminal_buffer(n) abort "{{{2
    return type(a:n) == v:t_number && a:n > 0 && getbufvar(a:n, '&bt', '') is# 'terminal'
endfu

fu s:log(msg, sfile, slnum) abort "{{{2
    if !s:DEBUG | return | endif
    let time = '" '..strftime('%H:%M:%S')
    let funcname = matchstr(a:sfile, '.*\.\.\zs.*')
    let sourcefile = split(execute('verb fu '..funcname), '\n')[1]
    let [sourcefile, lnum] = matchlist(sourcefile, '^\s*Last set from \(.*\)\s\+line \(\d\+\)')[1:2]
    let source = '" '..sourcefile..':'..(lnum + a:slnum)
    call writefile([time, source, a:msg], s:LOGFILE, 'a')
endfu

