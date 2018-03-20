fu! lg#window#get_modifier(...) abort "{{{1
"   ││                     │
"   ││                     └ optional flag meaning we're going to open a loc window
"   └┤
"    └ public so that it can be called in `vim-qf`
"     `qf#open()` in autoload/

    let origin = winnr()

    "  ┌ are we opening a loc window?
    "  │
    "  │      ┌ and does it display a TOC?
    "  │      │
    if a:0 && get(getloclist(0, {'title': 0}), 'title', '') =~# '\<TOC$'
        let mod = 'vert leftabove'
    else
        " are we at the bottom of the tabpage?
        noautocmd wincmd b
        if winnr() == origin
            let mod = 'botright'
        else
            noautocmd wincmd p
            " or maybe at the top?
            noautocmd wincmd t
            if winnr() == origin
                let mod = 'topleft'
            else
                " ok we're in a middle window
                noautocmd wincmd p
                " this will cause a vertical split to be opened on the left
                " if you would prefer on the right, write this instead:
                "
                "     let mod = 'vert rightbelow'
                "
                " For the moment, I prefer on the left, to be consistent with
                " how a TOC window is opened (on the left).
                let mod = 'vert leftabove'
            endif
        endif
    endif

    return mod
endfu

fu! lg#window#openable_anywhere() abort "{{{1
    " Why?{{{
    "
    " If we  press `gf` on a  filepath, it will replace  the preview buffer.
    " After that, we won't be able  to load the preview buffer back, because
    " we've set 'bt=nofile'.
    "
    " To avoid  this accident, we  remap `gf` so  that it splits  the window
    " before reading another file.
    "}}}
    nno  <buffer><nowait><silent>  gf  <c-w>Fzv
    "                                       │└┤
    "                                       │ └ open possible folds
    "                                       └── go to line number after colon

    nno  <buffer><nowait><silent>  <c-s>       <c-w>Fzv
    nno  <buffer><nowait><silent>  <c-v><c-v>  <c-w>Fzv:wincmd L<cr>
    nno  <buffer><nowait><silent>  <c-t>       <c-w>gFzv
    "                                          └───────┤
    "                                                  └ Alternative:  <c-w>Fzv<c-w>T
endfu

fu! lg#window#qf_open(type) abort "{{{1
    let we_are_in_qf = &bt is# 'quickfix'

    if !we_are_in_qf
        "
        "   ┌ dictionary: {'winid': 42}
        "   │
        let id = a:type is# 'loc'
        \            ?    getloclist(0, {'winid':0})
        \            :    getqflist(   {'winid':0})
        if get(id, 'winid', 0) == 0
            " Why :[cl]open? Are they valid commands here?{{{
            "
            " Probably not, because these commands  don't populate the qfl, they
            " just  open the  qf  window.
            "
            " However,  we  use   these  names  in  the   autocmd  listening  to
            " `QuickFixCmdPost` in `vim-qf`,  to decide whether we  want to open
            " the  qf window  unconditionally (:[cl]open),  or on  the condition
            " that the qfl contains at least 1 valid entry (`:[cl]window`).
            "
            " It allows us to do this in any plugin populating the qfl:
            "
            "         doautocmd <nomodeline> QuickFixCmdPost grep
            "             → open  the qf window  on the condition  it contains
            "               at  least 1 valid entry
            "
            "         doautocmd <nomodeline> QuickFixCmdPost copen
            "             → open the qf window unconditionally
            "}}}
            " Could we write sth simpler?{{{
            "
            " Yes:
            "         return (a:type is# 'loc' ? 'l' : 'c').'open'
            "
            " But, it wouldn't  open the qf window like our  autocmd in `vim-qf`
            " does.
            "}}}
            exe 'doautocmd <nomodeline> QuickFixCmdPost '.(a:type is# 'loc' ? 'l' : 'c').'open'
            return ''
        endif
        let id = id.winid

    " if we are already in the qf window, get back to the previous one
    elseif we_are_in_qf && a:type is# 'qf'
            return 'wincmd p'

    " if we are already in the ll window, get to the associated window
    elseif we_are_in_qf && a:type is# 'loc'
        let win_ids = gettabinfo(tabpagenr())[0].windows
        let loc_id  = win_getid()
        let id      = get(filter(copy(win_ids), {i,v ->    get(getloclist(v, {'winid': 0}), 'winid', 0)
        \                                               == loc_id
        \                                               && v != loc_id })
        \                 ,0,0)
    endif

    if id != 0
        call win_gotoid(id)
    endif
    return ''
endfu

fu! lg#window#quit() abort "{{{1
    " If we are in the command-line window, we want to close the latter,
    " and return without doing anything else (save session).
    "
    "         ┌─ return ':' in a command-line window,
    "         │  nothing in a regular buffer
    "         │
    if !empty(getcmdwintype())
        close
        return
    endif

    if tabpagenr('$') == 1 && winnr('$') == 1
        " If there's only one tab page and only one window, we want to close
        " the session.
        qall

    " In neovim, we could also test the existence of `b:terminal_job_pid`.
    elseif &bt is# 'terminal'
        bw!

    else
        let was_loclist = get(b:, 'qf_is_loclist', 0)
        " if the window we're closing is associated to a ll window,
        " close the latter too
        sil! lclose

        " if we were already in a loclist window, then `:lclose` has closed it,
        " and there's nothing left to close
        if was_loclist
            return
        endif

        " same thing for preview window, but only in a help buffer outside of
        " preview winwow
        if &bt is# 'help' && !&previewwindow
            pclose
        endif

        " create a new temporary file for the session we're going to save
        let s:undo_sessions = get(s:, 'undo_sessions', []) + [ tempname() ]

        try
            let session_save = v:this_session

            " don't save cwd
            let ssop_save = &ssop
            set ssop-=curdir

            exe 'mksession! '.s:undo_sessions[-1]
        catch
            return lg#catch_error()
        finally
            " if no session has been loaded so far, we don't want to see
            " `[S]` in the statusline;
            " and if a session was being tracked, we don't want to see `[S]`
            " but `[∞]`
            let v:this_session = session_save
            let &ssop = ssop_save
        endtry

        " We could also install an autocmd in our vimrc:
        "         au QuitPre * nested if &bt isnot# 'quickfix' | sil! lclose | endif
        "
        " Inspiration:
        " https://github.com/romainl/vim-qf/blob/5f971f3ed7f59ff11610c00b8a1e343e2dbae510/plugin/qf.vim#L64-L65
        "
        " But in this case, we couldn't close the window with `:close`.
        " We would have to use `:q`, because `:close` doesn't emit `QuitPre`.
        " For the moment, I prefer to use `:close` because it doesn't close
        " a window if it's the last one.

        try
            " Why :close instead of :quit ?{{{
            "
            "     Launch Vim with no file arguments:    $ vim
            "     Open a help buffer:                   :h autocmd
            "     Give focus to the unnamed buffer:     C-w w
            "     Quit the unnamed buffer:              :q
            "
            " Vim quits entirely instead of only closing the window.
            " It considers help buffers as unimportant.
            "
            " :close doesn't close a window if it's the last one.
            "}}}
            close
        catch
            return lg#catch_error()
        endtry
    endif
endfu

fu! lg#window#restore_closed(cnt) abort "{{{1
    if empty(get(s:, 'undo_sessions', ''))
        return
    endif

    sil! tabdo tabclose
    sil! windo close

    try
        let session_save = v:this_session
        "                                  ┌─ handle the case where we hit a too big number
        "                                  │
        let session_file = s:undo_sessions[max([ -a:cnt, -len(s:undo_sessions) ])]

        if !has('nvim')
            " Eliminate terminal buffers, to avoid E947.{{{
            "
            " In Vim,  a terminal buffer is  considered modified as long  as the
            " job is running.
            "
            " This is only the case in Vim, not Neovim.
            " Which means you can restore a session containing a terminal buffer
            " in Neovim (without its contents) but not in Vim.
            "
            " You can reproduce this kind of error, this way:
            "
            "         • open a terminal buffer
            "         • save the session (`:mksession file.vim`)
            "         • from the terminal buffer, restore the session (`:so file.vim`)
            "
            " Or:
            "         • open a terminal buffer
            "         • from the latter, execute:
            "                 :badd \!/bin/zsh
            "
            " FIXME:
            " Why does  the error  only occur  when `:badd`  is executed  from a
            " terminal buffer?
"}}}
            call writefile(filter(readfile(session_file),
            \                     { i,v -> v !~# '\v^badd \+\d+ \!/bin/%(bash|zsh)' }
            \                    ),
            \              session_file)
        endif

        " ┌ don't display the last filename;
        " │ if it's too long to fit on a single line,
        " │ it will trigger a press-enter prompt
        sil exe 'so '.session_file
        let s:undo_sessions = a:cnt == 1 ? s:undo_sessions[:-2] : []
        "                                                           │
        "            if we gave a count to restore several windows, ┘
        "
        " … we  probably want to  reset the  stack of sessions,  otherwise the
        " next time we  would hit `{number} leader u`, if  `{number}` is too big
        " we would end up in a weird old session we don't remember
        "
        " I'm still not sure it's the right thing to do, because
        " it prevents us from hitting `leader u` once again if
        " `{number}` was too small; time will tell

        " Idea:
        " We could add a 2nd stack which wouldn't be reset when we give a count, and
        " implement a 2nd mapping `leader U`, which could access this 2nd stack.
        " It could be useful if we hit `{number} leader u`, but `{number}` wasn't
        " big enough.
    catch
        return lg#catch_error()
    finally
        " When we undo the closing of a window, we don't want the statusline to
        " tell us we've restored a session with the indicator [S].
        " It's a detail of implementation we're not interested in.
        "
        " Besides, if a session is being tracked, it would temporarily replace
        " `[∞]` with `[S]`, which would be a wrong indication.
        let v:this_session = session_save
    endtry
endfu
