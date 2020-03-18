" Interface {{{1
fu lg#popup#nvim#basic(what, opts) abort "{{{2
    let [what, opts] = [a:what, a:opts]
    if type(what) == type(0) && bufexists(what)
        let bufnr = what
    else
        " create buffer
        call lg#popup#util#log('let bufnr = nvim_create_buf(v:false, v:true)', expand('<sfile>'), expand('<slnum>'))
        let bufnr = nvim_create_buf(v:false, v:true)

        " make Nvim wipe it automatically when it gets hidden
        call lg#popup#util#log('call nvim_buf_set_option(bufnr, "bh", "wipe")', expand('<sfile>'), expand('<slnum>'))
        call nvim_buf_set_option(bufnr, 'bh', 'wipe')

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
    " `nvim_open_win()` doesn't recognize a `highlight` key in its `{config}` argument.
    " Nevertheless, we want our `#popup#create()` to support such a key.
    let highlight = has_key(opts, 'highlight') ? remove(opts, 'highlight') : ''
    " `v:false` because – by default – we don't want Nvim to focus a float.{{{
    "
    " Just like Vim doesn't focus a popup.
    " Note that in  all examples from `:h api` where  `nvim_open_win()` is used,
    " `{enter}` is always `0` or `v:false`.
    " This confirms the intuition that a float  is meant to be as unobtrusive as
    " possible, thus not focused.
    "}}}
    let enter = has_key(opts, 'enter') ? remove(opts, 'enter') : v:false
    " open float
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

fu lg#popup#nvim#border(what, opts) abort "{{{2
    let [what, opts] = [a:what, a:opts]
    " `sil!` to suppress an error in case we invoked `#terminal()` without a `border` key
    sil! call remove(opts, 'border')
    let border_hl = has_key(opts, 'borderhighlight') ? remove(opts, 'borderhighlight') : 'Normal'

    " `nvim_open_win()` doesn't recognize the `pos` key, but the `anchor` key
    call s:set_anchor(opts)

    " to get the same position as in Vim (test with `#notification()`)
    " TODO: Is it still right?
    if opts.anchor[1] is# 'E'
        let opts.col += 1
    endif

    " reset geometry so that the text float fits inside the border float
    " TODO: Is `-1` and `-2` still right?
    let row_offset = opts.anchor[0] is# 'S' ? -1 : 1
    let col_offset = opts.anchor[1] is# 'E' ? -2 : 1
    call extend(opts, {
        \ 'row': opts.row + row_offset,
        \ 'col': opts.col + col_offset,
        \ })
    " create text float
    let is_not_focused = !has_key(opts, 'enter') || opts.enter == v:false
    let [text_bufnr, text_winid] = lg#popup#nvim#basic(what, opts)

    " create border float
    " We don't really need `'enter': v:false` here.{{{
    "
    " Because `#basic()` considers the `enter` key to be set to `v:false` by default.
    " But I prefer to set it explicitly here:
    "
    "    - in case one day we change the default value in `#basic()`
    "
    "    - to be more readable:
    "      we *never* want Nvim to focus the border, including when it has just been created;
    "      the code should reflect that
    "}}}
    call extend(opts, {
        \ 'col': opts.col - 1,
        \ 'width': opts.width + 4,
        \ 'height': opts.height + 2,
        \ 'enter': v:false,
        \ 'focusable': v:false,
        \ 'highlight': border_hl,
        \ })
    let border = s:get_border(opts.width, opts.height)
    let [border_bufnr, border_winid] = lg#popup#nvim#basic(border, opts)

    call win_gotoid(text_winid)
    call s:close_border_automatically(border_winid, text_winid)
    return [text_bufnr, text_winid, border_bufnr, border_winid]
endfu

fu lg#popup#nvim#terminal(what, opts) abort "{{{2
    let [what, opts] = [a:what, a:opts]
    call extend(opts, {'highlight': 'Normal', 'enter': v:true})
    let info = lg#popup#nvim#border(what, opts)
    if !lg#popup#util#is_terminal_buffer(what)
        call lg#popup#util#log('setl nomod bh=hide | call termopen(&shell)', expand('<sfile>'), expand('<slnum>'))
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
        " `#basic()` has set `'bh'` to wipe.{{{
        "
        " We need to reset it for a toggling terminal to work as expected.
        " We could  just clear the option,  but it would not  prevent a toggling
        " floating terminal buffer  from being wiped out when  being toggled off
        " if `'hidden'` is off.
        "}}}
        setl bh=hide
        " `termopen()` does not create a new buffer; it converts the current buffer into a terminal buffer
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
    call lg#popup#util#log('call timer_start('..time..', {-> nvim_win_close(g:winid, 1)})', expand('<sfile>'), expand('<slnum>'))
    call timer_start(time, {-> nvim_win_close(winid, 1)})
endfu
"}}}1
" Core {{{1
fu s:close_border_automatically(border, text) abort "{{{2
    " when the text float is closed, close the border too
    exe 'au WinClosed '..a:text..' ++once call nvim_win_close('..a:border..', 1)'
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

