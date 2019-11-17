fu lg#window#get_modifier(...) abort "{{{1
"  ├┘                     ├┘
"  │                      └ optional flag meaning we're going to open a loc window
"  └ public so that it can be called in `vim-qf`
"    `qf#open()` in autoload/

    let winnr = winnr()

    "  ┌ are we opening a loc window?
    "  │
    "  │      ┌ and does it display a TOC?
    "  │      │
    if a:0 && get(getloclist(0, {'title': 0}), 'title', '') =~# '\<TOC$'
        let mod = 'vert leftabove'

    " there's nothing above or below us
    elseif winnr('j') == winnr && winnr('k') == winnr
        let mod = 'botright'

    " we're at the top
    elseif winnr('k') == winnr
        let mod = 'topleft'

    " we're at the bottom
    elseif winnr('j') == winnr
        let mod = 'botright'

    " we're in a middle window
    else

        " this will cause a vertical split to be opened on the left
        " if you would prefer on the right, write this instead:
        "
        "     let mod = 'vert rightbelow'
        "
        " For the moment, I prefer on the left, to be consistent with
        " how a TOC window is opened (on the left).
        let mod = 'vert leftabove'
    endif

    return mod
endfu

fu lg#window#has_neighbor(dir, ...) abort "{{{1
    let winnr = a:0 ? a:1 : winnr()
    let neighbors = range(1, winnr('$'))

    if a:dir is# 'right'
        let rightedge = win_screenpos(winnr)[1] + winwidth(winnr) - 1
        let neighbors = map(neighbors, {_,v ->  v != winnr && win_screenpos(v)[1] > rightedge})

    elseif a:dir is# 'left'
        let leftedge = win_screenpos(winnr)[1] - 1
        let neighbors = map(neighbors, {_,v ->  v != winnr && win_screenpos(v)[1] < leftedge})

    elseif a:dir is# 'up'
        let upedge = win_screenpos(winnr)[0] - 1
        let neighbors = map(neighbors, {_,v ->  v != winnr && win_screenpos(v)[0] < upedge})

    elseif a:dir is# 'down'
        let downedge = win_screenpos(winnr)[0] + winheight(winnr) - 1
        let neighbors = map(neighbors, {_,v ->  v != winnr && win_screenpos(v)[0] > downedge})
    endif

    if index(neighbors, 1) >=0
        return 1
    endif
    return 0
endfu

fu lg#window#qf_open(type) abort "{{{1
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
            "         do <nomodeline> QuickFixCmdPost cwindow
            "         open  the qf window  on the condition  it contains at  least 1 valid entry~
            "
            "         do <nomodeline> QuickFixCmdPost copen
            "         open the qf window unconditionally~
            "}}}
            " Could we write sth simpler?{{{
            "
            " Yes:
            "         return (a:type is# 'loc' ? 'l' : 'c').'open'
            "
            " But, it wouldn't  open the qf window like our  autocmd in `vim-qf`
            " does.
            "}}}
            exe 'do <nomodeline> QuickFixCmdPost '..(a:type is# 'loc' ? 'l' : 'c')..'open'
            " Fix status line in previous window.{{{
            "
            " When we press  `z[` to open the qf window, the  status line of the
            " previous window wrongly displays `[QF]`.
            "
            " MWE:
            "
            "     do QuickFixCmdPost copen
            "}}}
            call lg#win_execute(lg#win_getid('#'), 'do <nomodeline> WinLeave')
            return ''
        endif
        let id = id.winid

    " if we are already in the qf window, get back to the previous one
    elseif we_are_in_qf && a:type is# 'qf'
        return 'wincmd p'

    " if we are already in the ll window, get to the associated window
    elseif we_are_in_qf && a:type is# 'loc'
        let id = get(getloclist(0, {'filewinid': 0}), 'filewinid', 0)
    endif

    if id != 0
        call win_gotoid(id)
    endif
    return ''
endfu

fu lg#window#quit() abort "{{{1
    " If we are in the command-line window, we want to close the latter,
    " and return without doing anything else (no session save).
    "
    "         ┌ return ':' in a command-line window,
    "         │ nothing in a regular buffer
    "         │
    if !empty(getcmdwintype()) | q | return | endif

    " a sign may be left in the sign column if you close an undotree diff panel with `:q` or `:close`
    if bufname('%') =~# '^diffpanel_\d\+$' | echo 'press "D" from the undotree buffer' | return | endif

    " If we're recording a macro, don't close the window; stop the recording.
    if reg_recording() isnot# '' | return feedkeys('q', 'in')[-1] | endif

    " In Nvim, a floating window has a number, and thus increases the value of `winnr('$')`.{{{
    " This is not the case for a popup window in Vim.
    "
    " Because of that, in Nvim, if we  press `SPC q` while only 1 regular window
    " – as  well as 1 floating  window – is  opened, `E444` is raised  (the code
    " path ends up executing `:close` instead of `:qall!`).
    " We need  to ignore  floating windows  when computing  the total  number of
    " windows opened  in the current  tab page; we do  this by making  sure that
    " `nvim_win_get_config(1234)` does *not* have the key `anchor`.
    "
    " From `:h nvim_open_win()`:
    "
    " > •  `anchor` : Decides which corner of the float to place at (row,col):
    " >   • "NW" northwest (default)
    " >   • "NE" northeast
    " >   • "SW" southwest
    " >   • "SE" southeast
    "
    " ---
    "
    " Is there a better way to detect whether a window is a float?
    "}}}
    if has('nvim')
        let winnr_max = len(filter(range(1, winnr('$')),
            \ {_,v -> ! has_key(nvim_win_get_config(win_getid(v)), 'anchor')}))
    else
        let winnr_max = winnr('$')
    endif

    " Quit everything if:{{{
    "
    "    - there's only 1 window in 1 tabpage
    "    - there're only 2 windows in 1 tabpage, one of which is a location list window
    "    - there're only 2 windows in 1 tabpage, the remaining one is a diff window
    "}}}
    if tabpagenr('$') == 1
       \ && (
       \         winnr_max == 1
       \      || winnr_max == 2
       \         && (
       \                index(map(getwininfo(), {_,v -> v.loclist}), 1) >= 0
       \             || getwinvar(winnr() == 1 ? 2 : 1, '&diff')
       \            )
       \    )
        qall!

    " In neovim, we could also test the existence of `b:terminal_job_pid`.
    elseif &bt is# 'terminal'
        bw!

    else
        let was_loclist = get(b:, 'qf_is_loclist', 0)
        " if the window we're closing is associated to a ll window, close the latter too
        " We could also install an autocmd in our vimrc:{{{
        "
        "     au QuitPre * ++nested if &bt isnot# 'quickfix' | sil! lclose | endif
        "
        " Inspiration:
        " https://github.com/romainl/vim-qf/blob/5f971f3ed7f59ff11610c00b8a1e343e2dbae510/plugin/qf.vim#L64-L65
        "
        " But in this  case, we couldn't close the current  window with `:close`
        " at the end of the function.
        " We would have to use `:q`, because `:close` doesn't emit `QuitPre`.
        " For the moment, I prefer to use `:close` because it doesn't close
        " a window if it's the last one.
        "}}}
        sil! lclose

        " if we were already in a loclist window, then `:lclose` has closed it,
        " and there's nothing left to close
        if was_loclist | return | endif

        " same thing for preview window, but only in a help buffer outside of
        " preview winwow
        if &bt is# 'help' && !&previewwindow | pclose | endif

        " create a new temporary file for the session we're going to save
        let s:undo_sessions = get(s:, 'undo_sessions', []) + [tempname()]

        try
            let session_save = v:this_session

            " save a minimum of info (in particular, don't save cwd; `curdir`)
            let ssop_save = &ssop
            set ssop=help,tabpages,winsize

            exe 'mksession! '..s:undo_sessions[-1]
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

        try
            " Why `:close` instead of `:quit`?{{{
            "
            "     $ vim
            "     :h
            "     C-w w
            "     :q
            "
            " Vim quits entirely instead of only closing the window.
            " It considers help buffers as unimportant.
            "
            " `:close` doesn't close a window if it's the last one.
            "}}}
            " Why adding a bang if `&l:bh is# 'wipe'`?{{{
            "
            " To avoid E37.
            " Vim refuses to wipe a modified buffer without a bang.
            " But if  I've set 'bh'  to 'wipe',  it's probably not  an important
            " buffer (ex: the one opened by `:DebugVimrc`).
            " So, I don't want to be bothered by an error.
            "}}}
            exe 'close'..(&l:bh is# 'wipe' ? '!' : '')
        catch
            return lg#catch_error()
        endtry
    endif
endfu

fu lg#window#restore_closed(cnt) abort "{{{1
    if empty(get(s:, 'undo_sessions', ''))
        return
    endif

    sil! noa tabdo tabclose
    sil! noa windo close

    try
        let session_save = v:this_session
        "                                  ┌ handle the case where we hit a too big number
        "                                  │
        let session_file = s:undo_sessions[max([-a:cnt, -len(s:undo_sessions)])]

        " We remove `:badd` commands from the session file, because{{{
        "
        " in Nvim, they  can prevent window-local options  from being re-applied
        " when we restore a closed window.
        "
        " MWE1:
        "
        "     $ nvim
        "     :sp $MYVIMRC
        "     SPC q
        "     SPC u
        "
        " MWE2:
        "
        "     $ nvim -Nu <(cat <<'EOF'
        "     set hidden ssop-=folds
        "     nno <space>q :<c-u>mksession! /tmp/.s.vim <bar> close<cr>
        "     nno <space>U :<c-u>so /tmp/.s.vim<cr>
        "     filetype plugin on
        "     au FileType vim setl fdm=marker
        "     EOF
        "     ) +'sp ~/.vim/vimrc'
        "
        "     " press SPC q
        "     " press SPC U
        "
        " In both examples, the folding is lost.
        "
        " ---
        "
        " The issue is due to a combination of 2 things:
        "
        "    - https://github.com/vim/vim/issues/4994
        "
        "    - in a Vim session file, `:badd` is run *after* `:edit`
        "      in a Nvim session file, `:badd` is run *before* `:edit`
        "
        " Vim session file (✔):
        "
        "     edit ~/.vim/vimrc
        "     wincmd t
        "     badd ~/.vim/vimrc
        "
        " Nvim session file (✘):
        "
        "     badd ~/.vim/vimrc
        "     edit ~/.vim/vimrc
        "     split
        "     wincmd w
        "     enew
        "     wincmd w
        "
        " ---
        "
        " Solution:
        " In the session file, remove every line starting with `badd`.
        "
        " Let's do  it even in  Vim, in  case the order  of the commands  in the
        " session file changes in the future, and the issue starts affecting Vim
        " too.
        " Besides,  `:badd` is  completely  useless here;  when  we source  this
        " session file, we  know that all its buffers are  already in the buffer
        " list (the session file was created during the current Vim session).
        "}}}
        " Ok but why you do the same for commands manipulating the arglist?{{{
        "
        " Look at the previous github issue; `:argadd` is mentioned.
        " Besides, it is useless to reset the arglist.
        "}}}
        call writefile(filter(readfile(session_file),
        \ {_,v -> v !~# '\m\C^\%(badd\|arg\%(global\|local\)\|%argdel\|silent! argdel \*\|$argadd\)\>'}), session_file)

        " ┌ don't display the last filename;
        " │ if it's too long to fit on a single line,
        " │ it will trigger a press-enter prompt
        sil exe 'so '..session_file
        let s:undo_sessions = a:cnt == 1 ? s:undo_sessions[:-2] : []
        "                                                          │
        "           if we gave a count to restore several windows, ┘
        "
        " … we  probably want to  reset the  stack of sessions,  otherwise the
        " next time we  would hit `{number} leader u`, if  `{number}` is too big
        " we would end up in a weird old session we don't remember
        "
        " I'm still not sure it's the right thing to do, because
        " it prevents us from hitting `leader u` once again if
        " `{number}` was too small; time will tell

        " Idea:
        " We could add a 2nd stack which wouldn't be reset when we give a count,
        " and implement a  2nd mapping `space C-u`, which could  access this 2nd
        " stack.   It  could  be  useful  if we  hit  `{number}  space  U`,  but
        " `{number}` wasn't big enough.
    catch
        return lg#catch_error()
    finally
        " When we undo the closing of a window, we don't want the statusline to
        " tell us we've restored a session with the indicator `[S]`.
        " It's a detail of implementation we're not interested in.
        "
        " Besides, if a session is being tracked, it would temporarily replace
        " `[∞]` with `[S]`, which would be a wrong indication.
        let v:this_session = session_save
    endtry
endfu
