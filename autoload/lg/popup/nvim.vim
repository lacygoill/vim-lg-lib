" Interface {{{1
fu lg#popup#nvim#simple(what, opts) abort "{{{2
    let [what, opts] = [a:what, a:opts]
    if type(what) == type(0)
        let bufnr = what
    else
        " create buffer
        let bufnr = nvim_create_buf(v:false, v:true)
        if type(what) == type('')
            let lines = [what]
        elseif type(what) == type([])
            let lines = what
        endif
        " This guard is important.{{{
        "
        " Without, the buffer would be changed,  and if this function is invoked
        " to create terminal popup, the next `termopen()` would fail:
        "
        "     let bufnr = nvim_create_buf(v:false, v:true)
        "     call nvim_buf_set_lines(bufnr, 0, -1, v:true, [])
        "     exe 'b '..bufnr
        "     call termopen(&shell)
        "
        " Imo, this is a bug, because we're in a scratch buffer:
        " https://github.com/neovim/neovim/issues/11962
        "
        " Without this  guard, you  would have to  execute `:setl  nomod` before
        " invoking `termopen()`.
        "
        " Anyway,  if there  is nothing  to write,  then there  is no  reason to
        " invoke `nvim_buf_set_lines()` and to change the buffer.
        "}}}
        if lines != ['']
            " write text in new buffer
            call nvim_buf_set_lines(bufnr, 0, -1, v:true, lines)
        endif
    endif
    " open window
    call extend(opts, {'relative': 'editor', 'style': 'minimal'}, 'keep')
    " `nvim_open_win()` doesn't recognize a 'highlight' key in its `{config}` argument.
    " Nevertheless, we want our `#popup#create()` to support such a key.
    let highlight = has_key(opts, 'highlight') ? remove(opts, 'highlight') : 'Normal'
    let winid = nvim_open_win(bufnr, v:true, opts)
    " highlight background
    call nvim_win_set_option(winid, 'winhl', 'NormalFloat:'..highlight)
    return [bufnr, winid]
endfu

fu lg#popup#nvim#with_border(what, opts) abort "{{{2
    let [what, opts] = [a:what, a:opts]
    let [width, height] = [opts.width, opts.height]
    " `sil!` to suppress an error in case we invoked `#terminal()` without a 'border' key
    sil! call remove(opts, 'border')

    " create border
    let border = s:get_border(width, height)
    let hl_save = get(opts, 'highlight', 'Normal')
    let border_hl = has_key(opts, 'borderhighlight') ? remove(opts, 'borderhighlight') : 'Normal'
    call extend(opts, {'highlight': border_hl})
    let [border_bufnr, border_winid] = lg#popup#nvim#simple(border, opts)
    call extend(opts, {'highlight': hl_save})

    " reset geometry so that the text of the "inner" float fits inside the border float
    call extend(opts, {
        \ 'width': opts.width - 4,
        \ 'height': opts.height - 2,
        \ 'row': opts.row + 1,
        \ 'col': opts.col + 2,
        \ })

    " open final window
    let info = lg#popup#nvim#simple(what, opts)
    call s:wipe_border_when_closing_float(border_bufnr)
    return info + [border_bufnr, border_winid]
endfu

fu lg#popup#nvim#terminal(what, opts) abort "{{{2
    let [what, opts] = [a:what, a:opts]
    call extend(opts, {'highlight': 'Normal'})
    let info = lg#popup#nvim#with_border(what, opts)
    if !lg#popup#util#is_terminal_buffer(what)
        " `termopen()` does not create a new buffer; it converts the current buffer into a terminal buffer
        call termopen(&shell)
    endif
    return info
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

fu s:wipe_border_when_closing_float(bufnr) abort "{{{2
    augroup wipe_border
        au! * <buffer>
        exe 'au BufHidden,BufWipeout <buffer> '
            \ ..'exe "au! wipe_border * <buffer>" | bw '..a:bufnr
    augroup END
endfu

