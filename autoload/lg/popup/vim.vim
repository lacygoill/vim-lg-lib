" Interface {{{1
fu lg#popup#vim#basic(what, opts) abort "{{{2
    let [what, opts, sfile] = [a:what, a:opts, expand('<sfile>')]
    if type(what) == type('') && what =~# '\n'
        let what = split(what, '\n')
    endif
    call extend(opts, #{line: remove(opts, 'row'), zindex: s:get_zindex()}, 'keep')

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
    call lg#popup#util#log(cmd, sfile, expand('<slnum>'))
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
    call lg#popup#util#log(cmd, sfile, expand('<slnum>'))
    exe cmd
    return [winbufnr(winid), winid]
endfu

fu lg#popup#vim#border(what, opts) abort "{{{2
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
    call lg#popup#util#set_borderchars(opts)
    return lg#popup#vim#basic(what, opts)
endfu

fu lg#popup#vim#terminal(what, opts) abort "{{{2
    let [what, opts, sfile] = [a:what, a:opts, expand('<sfile>')]
    " If `what` is the number of a terminal buffer, don't create yet another one.{{{
    "
    " Just use `what`.
    " This is useful, in particular, when toggling a popup terminal.
    "}}}
    if lg#popup#util#is_terminal_buffer(what)
        let bufnr = what
    else
        let cmd = 'let bufnr = term_start(&shell, #{hidden: v:true, term_finish: ''close'', term_kill: ''hup''})'
        call lg#popup#util#log(cmd, sfile, expand('<slnum>'))
        exe cmd
    endif
    " in Terminal-Normal mode, don't highlight empty cells with `Pmenu` (same thing for padding cells)
    call extend(opts, #{highlight: 'Normal'})
    " make sure a border is drawn even if the `border` key was not set
    call extend(opts, #{border: get(opts, 'border', [])})
    let info = lg#popup#vim#border(bufnr, opts)
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

