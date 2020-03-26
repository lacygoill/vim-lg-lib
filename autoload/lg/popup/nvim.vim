" Interface {{{1
fu lg#popup#nvim#basic(what, opts) abort "{{{2
    let [what, opts, sfile] = [a:what, a:opts, expand('<sfile>')]

    " remove some keys
    call s:sanitize(opts)
    if has_key(opts, 'firstline') | let firstline = remove(opts, 'firstline') | endif
    if has_key(opts, 'moved') | let moved = remove(opts, 'moved') | endif
    if has_key(opts, 'highlight') | let highlight = remove(opts, 'highlight') | endif
    " `v:false` because – by default – we don't want Nvim to focus a float.{{{
    "
    " Just like Vim doesn't focus a popup.
    " Note that in  all examples from `:h api` where  `nvim_open_win()` is used,
    " `{enter}` is always `0` or `v:false`.
    " This confirms the intuition that a float  is meant to be as unobtrusive as
    " possible, thus not focused.
    "}}}
    let enter = has_key(opts, 'enter') ? remove(opts, 'enter') : v:false

    " set some keys
    call s:set_anchor(opts)
    call extend(opts, {
        "\ these offsets are there to get the same position as in Vim
        \ 'row': opts.row - 1 + (opts.anchor is# 'SE') + (opts.anchor is# 'SW'),
        \ 'col': opts.col - 1 + (opts.anchor is# 'NE') + (opts.anchor is# 'SE'),
        \ })
    call extend(opts, {
        \ 'focusable': v:false,
        \ 'relative': 'editor',
        \ 'style': 'minimal'
        \ }, 'keep')

    if type(what) == type(0) && bufexists(what)
        let bufnr = what
    else
        " create buffer
        let cmd = 'let bufnr = nvim_create_buf(v:false, v:true)'
        call lg#popup#util#log(cmd, sfile, expand('<slnum>'))
        exe cmd

        " make Nvim wipe it automatically when it gets hidden
        let cmd = 'call nvim_buf_set_option(bufnr, ''bh'', ''wipe'')'
        call lg#popup#util#log(cmd, sfile, expand('<slnum>'))
        exe cmd

        let lines = lg#popup#util#get_lines(what)
        if lines != []
            " write text in new buffer
            let cmd = printf('call nvim_buf_set_lines(bufnr, 0, -1, v:true, %s)', lines)
            call lg#popup#util#log(cmd, sfile, expand('<slnum>'))
            exe cmd
        endif
    endif

    " open float
    let cmd = printf('let winid = nvim_open_win(bufnr, %s, %s)', enter, opts)
    call lg#popup#util#log(cmd, sfile, expand('<slnum>'))
    exe cmd

    " highlight background
    if exists('highlight')
        let cmd = printf("call nvim_win_set_option(winid, 'winhl', 'NormalFloat:%s')", highlight)
        call lg#popup#util#log(cmd, sfile, expand('<slnum>'))
        exe cmd
    endif

    " set topline of the float if one is specified via `firstline`
    if exists('firstline')
        let cmd = "call setwinvar(winid, '&so', 0)"
        call lg#popup#util#log(cmd, sfile, expand('<slnum>'))
        exe cmd
        let cmd = printf("call lg#win_execute(winid, '%d | norm! zt')", firstline)
        call lg#popup#util#log(cmd, sfile, expand('<slnum>'))
        exe cmd
    endif

    " close float automatically when cursor moves
    if exists('moved')
        " `nvim_win_is_valid()` is a necessary sanity check.{{{
        "
        " Your plugin may have another autocmd which closed the window before.
        "}}}
        let cmd = printf("exe 'au CursorMoved <buffer> ++once if nvim_win_is_valid('..%d..')"
            \ .."| call nvim_win_close('..%d..', 1)' | endif", winid, winid)
        call lg#popup#util#log(cmd, sfile, expand('<slnum>'))
        exe cmd
    endif

    return [bufnr, winid]
endfu

fu lg#popup#nvim#border(what, opts) abort "{{{2
    let [what, opts] = [a:what, a:opts]
    " `sil!` to suppress an error in case we invoked `#terminal()` without a `border` key
    sil! call remove(opts, 'border')
    " Vim uses `Pmenu` by default; let's do the same in Nvim
    let border_hl = has_key(opts, 'borderhighlight') ? remove(opts, 'borderhighlight') : 'Pmenu'

    " `nvim_open_win()` doesn't recognize the `pos` key, but the `anchor` key
    call s:set_anchor(opts)

    " reset geometry so that the text float fits inside the border float
    " (the offsets are there to get the same position as in Vim)
    call extend(opts, {
        \ 'row': opts.row + 1 + (opts.anchor[0] is# 'S' ? 2 : 0),
        \ 'col': opts.col + 1 - (opts.anchor[1] is# 'E' ? opts.width + 3 : 0),
        \ })
    " create text float
    let is_focused = get(opts, 'enter', v:false)
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

    if is_focused
        call win_gotoid(text_winid)
    endif

    call s:close_border_automatically(border_winid, text_winid)
    return [text_bufnr, text_winid, border_bufnr, border_winid]
endfu

fu lg#popup#nvim#terminal(what, opts) abort "{{{2
    let [what, opts, sfile] = [a:what, a:opts, expand('<sfile>')]
    call extend(opts, {
        \ 'highlight': 'Normal',
        \ 'enter': v:true,
        \ 'focusable': v:true,
        \ })
    let info = lg#popup#nvim#border(what, opts)
    if !lg#popup#util#is_terminal_buffer(what)
        " `nomod` to avoid "Can only call this function in an unmodified buffer".{{{
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
        " `bh=hide` because `#basic()` has set `'bh'` to wipe.{{{
        "
        " We need to reset it for a toggling terminal to work as expected.
        " We could  just clear the option,  but it would not  prevent a toggling
        " floating terminal buffer  from being wiped out when  being toggled off
        " if `'hidden'` is off.
        "}}}
        " `termopen()` does not create a new buffer; it converts the current buffer into a terminal buffer
        let cmd = 'setl nomod bh=hide | call termopen(&shell)'
        call lg#popup#util#log(cmd, sfile, expand('<slnum>'))
        exe cmd
    endif
    return info
endfu

fu lg#popup#nvim#notification(what, opts) abort "{{{2
    let [what, opts, sfile] = [a:what, a:opts, expand('<sfile>')]
    let lines = lg#popup#util#get_lines(what)
    let n_opts = lg#popup#util#get_notification_opts(lines)
    let time = remove(n_opts, 'time')
    call extend(opts, n_opts, 'keep')
    let [_, winid, _, _] = lg#popup#create(lines, opts)
    let cmd = printf('call timer_start(%d, {-> nvim_win_close(%d, 1)})', time, winid)
    call lg#popup#util#log(cmd, sfile, expand('<slnum>'))
    exe cmd
endfu
"}}}1
" Core {{{1
fu s:close_border_automatically(border, text) abort "{{{2
    " when the text float is closed, close the border too
    exe 'au WinClosed '..a:text..' ++once call nvim_win_close('..a:border..', 1)'
endfu
"}}}1
" Util {{{1
fu s:sanitize(opts) abort "{{{2
    " remove keys which:{{{
    "
    "    - we could use in Vim
    "    - are not recognized in Nvim
    "    - can't be used to do anything useful because there is no equivalent mechanism in Nvim
    "}}}
    sil! call remove(a:opts, 'filter')
    sil! call remove(a:opts, 'filtermode')
    sil! call remove(a:opts, 'padding')
endfu

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

