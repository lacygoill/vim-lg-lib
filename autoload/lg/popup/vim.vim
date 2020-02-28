fu lg#popup#vim#simple(what, opts) abort "{{{1
    let [what, opts] = [a:what, a:opts]
    call extend(opts, #{
        \ line: remove(opts, 'row'),
        \ minwidth: opts.width,
        \ maxwidth: opts.width,
        \ minheight: opts.height,
        \ maxheight: opts.height,
        \ zindex: 50,
        \ }, 'keep')
    " TODO: Why did we do that?
    "     call extend(opts, #{borderhighlight: [get(opts, 'borderhighlight', '')]})
    let winid = popup_create(what, opts)
endfu

fu lg#popup#vim#with_border(what, opts) abort "{{{1
    let [what, opts] = [a:what, a:opts]
    let [width, height] = [opts.width, opts.height]

    " reset geometry so that the inner text fits inside the border
    call extend(opts, {
        \ 'width': opts.width - 4,
        \ 'height': opts.height - 2,
        \ 'row': opts.row + 1,
        \ 'col': opts.col + 2,
        \ })

    " open final window
    call s:set_borderchars(opts)
    call lg#popup#vim#simple(what, opts)
endfu

fu lg#popup#vim#terminal(what, opts) abort "{{{1
    let bufnr = term_start(&shell, #{hidden: v:true})
    call lg#popup#util#set_borderchars(a:opts)
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
    call extend(a:opts, #{highlight: 'Normal'})
    " TODO: Is it necessary?  We do it with `C-g C-g`...{{{
    "
    " Once you've implemented the popup terminal for Nvim, compare the resulting windows.
    " Make sure the space occupied by the shell commands is exactly the same.
    "}}}
    call extend(#{padding: [0,1,0,1]}, a:opts)
    call lg#popup#vim#simple(bufnr, a:opts)
    call s:fire_terminal_events()
endfu

fu s:fire_terminal_events() abort
    if exists('#TerminalWinOpen') | do <nomodeline> TerminalWinOpen | endif
    if exists('#User#TermEnter') | do <nomodeline> User TermEnter | endif
endfu

