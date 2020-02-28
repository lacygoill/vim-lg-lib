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
        " write text in new buffer
        call nvim_buf_set_lines(bufnr, 0, -1, v:true, lines)
    endif
    " open window
    call extend(opts, {'relative': 'editor', 'style': 'minimal'}, 'keep')
    " `nvim_open_win()` doesn't recognize a 'highlight' key in its `{config}` argument.
    " Nevertheless, we want our `#popup#create()` to support such a key.
    let highlight = has_key(opts, 'highlight') ? remove(opts, 'highlight') : 'Normal'
    let winid = nvim_open_win(bufnr, v:true, opts)
    " highlight background
    call nvim_win_set_option(winid, 'winhl', 'NormalFloat:'..highlight)
    return bufnr
endfu

fu lg#popup#nvim#with_border(what, opts) abort "{{{2
    let [what, opts] = [a:what, a:opts]
    let [width, height] = [opts.width, opts.height]

    " create border
    let border = s:get_border(width, height)
    let hl_save = get(opts, 'highlight', 'Normal')
    let border_hl = has_key(opts, 'borderhighlight') ? remove(opts, 'borderhighlight') : 'Normal'
    call extend(opts, {'highlight': border_hl})
    let border_bufnr = lg#popup#nvim#simple(border, opts)
    call extend(opts, {'highlight': hl_save})

    " reset geometry so that the inner text fits inside the border
    call extend(opts, {
        \ 'width': opts.width - 4,
        \ 'height': opts.height - 2,
        \ 'row': opts.row + 1,
        \ 'col': opts.col + 2,
        \ })

    " open final window
    call lg#popup#nvim#simple(what, opts)
    call s:wipe_border_when_closing_float(border_bufnr)
endfu

fu lg#popup#nvim#terminal(what, opts) abort "{{{2
    call extend(a:opts, {'highlight': 'Normal'})
    call lg#popup#nvim#with_border(a:what, a:opts)
    setl nomod
    call termopen(&shell)
endfu
"}}}1
" Util {{{1
fu s:get_border(width, height) abort "{{{2
    " TODO: use the characters from `#set_borderchars()`
    let top = '┌'..repeat('─', a:width - 2)..'┐'
    let mid = '│'..repeat(' ', a:width - 2)..'│'
    let bot = '└'..repeat('─', a:width - 2)..'┘'
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

