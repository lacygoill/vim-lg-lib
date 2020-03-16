" Interface {{{1
fu lg#popup#nvim#simple(what, opts) abort "{{{2
    let [what, opts] = [a:what, a:opts]
    if type(what) == type(0) && bufexists(what)
        let bufnr = what
    else
        " create buffer
        call lg#popup#util#log('let bufnr = nvim_create_buf(v:false, v:true)',
            \ expand('<sfile>'), expand('<slnum>'))
        let bufnr = nvim_create_buf(v:false, v:true)
        let lines = lg#popup#util#get_lines(what)
        if lines != []
            " write text in new buffer
            call lg#popup#util#log('call nvim_buf_set_lines(bufnr, 0, -1, v:true, '..string(lines)..')',
                \ expand('<sfile>'), expand('<slnum>'))
            call nvim_buf_set_lines(bufnr, 0, -1, v:true, lines)
        endif
    endif
    call s:set_anchor(opts)
    call extend(opts, {'row': opts.row - 1, 'col': opts.col - 1})
    call extend(opts, {'relative': 'editor', 'style': 'minimal'}, 'keep')
    " `nvim_open_win()` doesn't recognize a 'highlight' key in its `{config}` argument.
    " Nevertheless, we want our `#popup#create()` to support such a key.
    let highlight = has_key(opts, 'highlight') ? remove(opts, 'highlight') : ''
    let enter = has_key(opts, 'enter') ? remove(opts, 'enter') : v:false
    " open window
    call lg#popup#util#log('let winid = nvim_open_win(bufnr, '..string(enter)..', '..string(opts)..')',
        \ expand('<sfile>'), expand('<slnum>'))
    let winid = nvim_open_win(bufnr, enter, opts)
    " highlight background
    if highlight isnot# ''
        call lg#popup#util#log("call nvim_win_set_option(winid, 'winhl', 'NormalFloat:"..highlight.."')",
            \ expand('<sfile>'), expand('<slnum>'))
        call nvim_win_set_option(winid, 'winhl', 'NormalFloat:'..highlight)
    endif
    return [bufnr, winid]
endfu

fu lg#popup#nvim#with_border(what, opts) abort "{{{2
    let [what, opts] = [a:what, a:opts]
    " `sil!` to suppress an error in case we invoked `#terminal()` without a 'border' key
    sil! call remove(opts, 'border')

    " `nvim_open_win()` doesn't recognize the `pos` key, but the `anchor` key
    call s:set_anchor(opts)

    " to get the same geometry as in Vim (test with `#notification()`)
    if opts.anchor[1] is# 'E'
        let opts.col += 1
    endif

    " create border
    let border = s:get_border(opts.width, opts.height)
    let border_hl = has_key(opts, 'borderhighlight') ? remove(opts, 'borderhighlight') : 'Normal'
    let _opts = extend(deepcopy(opts), {'highlight': border_hl, 'focusable': v:false})
    let [border_bufnr, border_winid] = lg#popup#nvim#simple(border, _opts)

    " reset geometry so that the text of the "inner" float fits inside the border float
    let row_offset = opts.anchor[0] is# 'S' ? -1 : 1
    let col_offset = opts.anchor[1] is# 'E' ? -2 : 2
    " TODO: Here we write `-4` and `-2`.  For Vim, we write:{{{
    "
    "     - 2 - (l_pad + r_pad)
    "     - 2 - (t_pad + b_pad)
    "
    " Should we do sth simlar here?
    "}}}
    call extend(opts, {
        \ 'width': max([1, opts.width - 4]),
        \ 'height': max([1, opts.height - 2]),
        \ 'row': opts.row + row_offset,
        \ 'col': opts.col + col_offset,
        \ })

    " open final window
    let window_not_entered = !has_key(opts, 'enter') || opts.enter == v:false
    let [text_bufnr, text_winid] = lg#popup#nvim#simple(what, opts)
    call s:wipe_border_when_closing_float(border_bufnr, text_bufnr)
    if window_not_entered
        " Make sure the contents of the window is visible immediately.{{{
        "
        " It won't be if you've used `'enter': v:false`.
        " That's because in that case, the border window is displayed right on top.
        " Solution: focus the "inner" window, then get back to the original window.
        "}}}
        let curwin = win_getid()
        call win_gotoid(text_winid)
        call timer_start(0, {-> win_gotoid(curwin)})
    endif
    return [text_bufnr, text_winid, border_bufnr, border_winid]
endfu

fu lg#popup#nvim#terminal(what, opts) abort "{{{2
    let [what, opts] = [a:what, a:opts]
    call extend(opts, {'highlight': 'Normal', 'enter': v:true})
    let info = lg#popup#nvim#with_border(what, opts)
    if !lg#popup#util#is_terminal_buffer(what)
        " To avoid "Can only call this function in an unmodified buffer".{{{
        "
        " If the buffer  has been changed, and if function  is invoked to create
        " terminal popup, the next `termopen()` would fail:
        "
        "     let bufnr = nvim_create_buf(v:false, v:true)
        "     call nvim_buf_set_lines(bufnr, 0, -1, v:true, [])
        "     exe 'b '..bufnr
        "     call termopen(&shell)
        "
        " Imo, this is a bug, because we're in a scratch buffer:
        " https://github.com/neovim/neovim/issues/11962
        "}}}
        setl nomod
        " `termopen()` does not create a new buffer; it converts the current buffer into a terminal buffer
        call lg#popup#util#log('call termopen(&shell)', expand('<sfile>'), expand('<slnum>'))
        call termopen(&shell)
    endif
    return info
endfu

fu lg#popup#nvim#notification(what, opts) abort "{{{2
    let [what, opts] = [a:what, a:opts]
    let lines = lg#popup#util#get_lines(what)
    let n_opts = lg#popup#util#get_notification_opts(lines)
    let time = remove(n_opts, 'time')
    call extend(opts, n_opts, 'keep')
    let [_, winid, _, _] = lg#popup#create(lines, opts)
    call timer_start(time, {-> nvim_win_close(winid, 1)})
endfu
"}}}1
" Core {{{1
fu s:wipe_border_when_closing_float(border_bufnr, text_bufnr) abort "{{{2
    augroup wipe_border
        exe 'au! * <buffer='..a:text_bufnr..'>'
        exe 'au BufHidden,BufWipeout <buffer='..a:text_bufnr..'> '
            \ ..'exe "au! wipe_border * <buffer>" | bw '..a:border_bufnr
    augroup END
endfu
"}}}1
" Util {{{1
fu s:get_border(width, height) abort "{{{2
    let [t, r, b, l, tl, tr, br, bl] = lg#popup#util#get_borderchars()
    let top = tl..repeat(t, a:width - 2)..tr
    let mid = l..repeat(' ', a:width - 2)..r
    let bot = bl..repeat(b, a:width - 2)..br
    let border = [top] + repeat([mid], a:height - 2) + [bot]
    return border
endfu

fu s:set_anchor(opts) abort "{{{2
    if !has_key(a:opts, 'pos')
        let a:opts.pos = 'topleft'
    endif
    " TODO: `'pos': 'center'` has no direct equivalent in Nvim.  Try to emulate it.
    call extend(a:opts, {
        \ 'anchor': {
        \     'topleft': 'NW',
        \     'topright': 'NE',
        \     'botleft': 'SW',
        \     'botright': 'SE',
        \ }[a:opts.pos]})
    call remove(a:opts, 'pos')
endfu

