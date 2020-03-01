" Interface {{{1
fu lg#popup#vim#simple(what, opts) abort "{{{2
    let [what, opts] = [a:what, a:opts]
    call extend(opts, #{line: remove(opts, 'row'), zindex: 50}, 'keep')
    " Vim doesn't recognize the 'width' and 'height' keys.
    call extend(opts, #{
        \ minwidth: opts.width,
        \ maxwidth: opts.width,
        \ minheight: opts.height,
        \ maxheight: opts.height,
        \ }, 'keep')
    sil! call remove(opts, 'width') | sil! call remove(opts, 'height')
    let winid = popup_create(what, opts)
    return [winbufnr(winid), winid]
endfu

fu lg#popup#vim#with_border(what, opts) abort "{{{2
    let [what, opts] = [a:what, a:opts]
    let [width, height] = [opts.width, opts.height]

    " reset geometry so that the inner text fits inside the border
    call extend(opts, {
        \ 'width': opts.width - 4,
        \ 'height': opts.height - 2,
        \ 'row': opts.row + 1,
        \ 'col': opts.col + 2,
        \ })
    " Vim expects the 'borderhighlight' key to be a list.  We want a string; do the conversion.
    call extend(opts, #{borderhighlight: [get(opts, 'borderhighlight', '')]})

    " open final window
    call lg#popup#util#set_borderchars(opts)
    return lg#popup#vim#simple(what, opts)
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
        let bufnr = term_start(&shell, #{hidden: v:true})
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
    " Currently necessary to get the exact same geometry for a Vim and Nvim popup terminal.
    call extend(opts, #{padding: [0,1,0,1]}, 'keep')
    " We really need both the `max...` keys and the `min...` keys.{{{
    "
    " Otherwise, in  a popup terminal, when  we scroll back in  a long shell
    " command output,  the terminal buffer  contents goes beyond the  end of
    " the window.
    "}}}
    call extend(opts, #{
        \ minwidth: opts.width,
        \ maxwidth: opts.width,
        \ minheight: opts.height,
        \ maxheight: opts.height,
        \ }, 'keep')
    let info = lg#popup#vim#with_border(bufnr, opts)
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

