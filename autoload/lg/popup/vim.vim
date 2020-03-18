" Interface {{{1
fu lg#popup#vim#basic(what, opts, ...) abort "{{{2
    let [what, opts, is_term] = [a:what, a:opts, a:0]
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
    call lg#popup#util#log(printf('call popup_create(%s, %s)',
        \ is_term ? 'bufnr' : string(what), string(opts)), expand('<sfile>'), expand('<slnum>'))
    let winid = popup_create(what, opts)
    return [winbufnr(winid), winid]
endfu

fu lg#popup#vim#border(what, opts, ...) abort "{{{2
    let [what, opts, is_term] = [a:what, a:opts, a:0]

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
        "\ TODO: to get the same position as in Nvim?
        "\ TODO: check out how we wrote `s:get_geometry()` in `vim-terminal`;
        "\ we wrote `-4` and `-2`; will it work if we use different paddings?
        \ col: opts.col - 1,
        \ width: opts.width,
        \ height: opts.height,
        \ })
    " Vim expects the 'borderhighlight' key to be a list.  We want a string; do the conversion.
    call extend(opts, #{borderhighlight: [get(opts, 'borderhighlight', '')]})

    " open final window
    call lg#popup#util#set_borderchars(opts)
    return call('lg#popup#vim#basic', [what, opts] + (is_term ? [v:true] : []))
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
    " Make sure empty cells are highlighted just like non-empty cells in Terminal-Normal mode.{{{
    "
    " When  you're in  Terminal-Job  mode, everything  is highlighted  according
    " to  Vim's  internal   terminal  palette  (which  can   be  configured  via
    " `g:terminal_ansi_colors`).
    "
    " When you're in Terminal-Normal mode:
    "
    "    - the non-empty cells are still highlighted according to Vim's internal terminal palette
    "    - the empty cells are highlighted according the 'highlight' key, or `Pmenu` as a fallback
    "
    " We want all cells to be highlighted in the exact same way; so we make sure
    " that empty cells are highlighted just like the non-empty ones.
    "
    " ---
    "
    " The same issue applies to empty  cells in the padding areas, regardless of
    " the mode you're in.
    "}}}
    call extend(opts, #{highlight: 'Normal'})
    " make sure a border is drawn even if the `border` key was not set
    call extend(opts, #{border: get(opts, 'border', [])})
    let info = lg#popup#vim#border(bufnr, opts, 'is_term')
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

