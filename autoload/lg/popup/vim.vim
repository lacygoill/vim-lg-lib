" Interface {{{1
fu lg#popup#vim#simple(what, opts, ...) abort "{{{2
    let [what, opts, is_term] = [a:what, a:opts, a:0]
    if type(what) == type('') && what =~# '\n'
        let what = split(what, '\n')
    endif
    call extend(opts, #{line: remove(opts, 'row'), zindex: s:get_zindex()}, 'keep')
    " Vim doesn't recognize the 'width' and 'height' keys.
    call extend(opts, #{
        \ minwidth: opts.width,
        \ maxwidth: opts.width,
        \ minheight: opts.height,
        \ maxheight: opts.height,
        \ })
    call remove(opts, 'width') | call remove(opts, 'height')
    call lg#popup#util#log(printf('call popup_create(%s, %s)',
        \ is_term ? 'bufnr' : string(what), string(opts)), expand('<sfile>'), expand('<slnum>'))
    let winid = popup_create(what, opts)
    return [winbufnr(winid), winid]
endfu

fu lg#popup#vim#with_border(what, opts, ...) abort "{{{2
    let [what, opts, is_term] = [a:what, a:opts, a:0]
    let [width, height] = [opts.width, opts.height]

    " reset geometry so that the inner text fits inside the border
    call extend(opts, #{padding: [0,1,0,1]}, 'keep')
    let [t_pad, r_pad, b_pad, l_pad] = opts.padding
    call extend(opts, #{
        \ width: opts.width - 2 - (l_pad + r_pad),
        \ height: opts.height - 2 - (t_pad + b_pad),
        \ })
    " Vim expects the 'borderhighlight' key to be a list.  We want a string; do the conversion.
    call extend(opts, #{borderhighlight: [get(opts, 'borderhighlight', '')]})

    " open final window
    call lg#popup#util#set_borderchars(opts)
    return call('lg#popup#vim#simple', [what, opts] + (is_term ? [v:true] : []))
endfu

fu lg#popup#vim#terminal(what, opts) abort "{{{2
    let [what, opts] = [a:what, a:opts]
    " If `what` is the number of a terminal buffer, don't create yet another one.{{{
    "
    " Just use `what`.
    " This is useful, in particular, when toggling a popup terminal.
    "}}}
    if lg#popup#util#is_terminal_buffer(what)
        let bufnr = what
    else
        call lg#popup#util#log('let bufnr = term_start(&shell, #{hidden: v:true, term_kill: ''hup''})',
            \ expand('<sfile>'), expand('<slnum>'))
        " `term_kill: 'hup'` suppresses `E947` when you try to quit Vim with `:q` or `:qa`.{{{
        "
        "     E947: Job still running in buffer "!/usr/local/bin/zsh"
        "}}}
        let bufnr = term_start(&shell, #{hidden: v:true, term_kill: 'hup'})
    endif
    call lg#popup#util#set_borderchars(opts)
    " Make sure 'highlight' is 'Normal' no matter what.{{{
    "
    " Otherwise, the background may be colored with 2 different colors which is jarring.
    "
    " Vim uses the  HG group set by  the 'highlight' key for  empty cells (don't
    " contain any  character), and only  in Terminal-Normal mode; or  `Pmenu` if
    " 'highlight' is not set.
    " Otherwise, I think Vim highlights the cells with the colors defined in its
    " terminal palette.
    "}}}
    call extend(opts, #{highlight: 'Normal'})
    " make sure a border is drawn no matter what
    call extend(opts, #{border: get(opts, 'border', [])})
    " We really need both the `max...` keys and the `min...` keys.{{{
    "
    " Otherwise, in  a popup terminal, when  we scroll back in  a long shell
    " command output,  the terminal buffer  contents goes beyond the  end of
    " the window.
    "}}}
    " The padding key is currently necessary to get the exact same geometry for a Vim and Nvim popup terminal.{{{
    "
    " But more generally, I  like to add one space between  the start/end of the
    " text and the left/right borders.  It's more aesthetically pleasing.
    "}}}
    call extend(opts, #{
        \ minwidth: opts.width,
        \ maxwidth: opts.width,
        \ minheight: opts.height,
        \ maxheight: opts.height,
        \ padding: [0,1,0,1],
        \ }, 'keep')
    let info = lg#popup#vim#with_border(bufnr, opts, 'is_term')
    call s:fire_terminal_events()
    return info
endfu

fu lg#popup#vim#notification(what, opts) abort "{{{2
    let [what, opts] = [a:what, a:opts]
    let lines = lg#popup#util#get_lines(what)
    let n_opts = lg#popup#util#get_notification_opts(lines)
    call extend(opts, n_opts, 'keep')
    call lg#popup#create(lines, opts)
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

