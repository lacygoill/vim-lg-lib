vim9script

import Catch from 'lg.vim'

export def GetModifier(OpenLoc = v:false): string #{{{1
    let winnr = winnr()

    let mod: string
    if OpenLoc && getloclist(0, {'title': 0}).title =~# '\<TOC$'
        mod = 'vert leftabove'

    # there's nothing above or below us
    elseif winnr('j') == winnr && winnr('k') == winnr
        mod = 'botright'

    # we're at the top
    elseif winnr('k') == winnr
        mod = 'topleft'

    # we're at the bottom
    elseif winnr('j') == winnr
        mod = 'botright'

    # we're in a middle window
    else
        # this will cause a vertical split to be opened on the left
        # if you would prefer on the right, write this instead:
        #
        #     mod = 'vert rightbelow'
        #
        # For the moment, I prefer on the left, to be consistent with
        # how a TOC window is opened (on the left).
        mod = 'vert leftabove'
    endif

    return mod
endfu

def QfOpenOrFocus(type: string): number #{{{1
    let we_are_in_qf = &bt == 'quickfix'
    let winid: number
    if !we_are_in_qf
        let winid = type == 'loc'
            ? getloclist(0, {'winid': 0}).winid
            : getqflist({'winid': 0}).winid
        if !winid
            # Why `:[cl]open`? Are they valid commands here?{{{
            #
            # Probably not, because these commands  don't populate the qfl, they
            # just  open the  qf  window.
            #
            # However,  we  use   these  names  in  the   autocmd  listening  to
            # `QuickFixCmdPost` in `vim-qf`,  to decide whether we  want to open
            # the  qf window  unconditionally (:[cl]open),  or on  the condition
            # that the qfl contains at least 1 valid entry (`:[cl]window`).
            #
            # It lets us do this in any plugin populating the qfl:
            #
            #     do <nomodeline> QuickFixCmdPost cwindow
            #     open  the qf window  on the condition  it contains at  least 1 valid entry~
            #
            #     do <nomodeline> QuickFixCmdPost copen
            #     open the qf window unconditionally~
            #}}}
            # Could we write sth simpler?{{{
            #
            # Yes:
            #
            #     exe (type == 'loc' ? 'l' : 'c') .. 'open'
            #
            # But, it wouldn't open the qf window like our autocmd in `vim-qf` does.
            #}}}
            exe 'do <nomodeline> QuickFixCmdPost ' .. (type == 'loc' ? 'l' : 'c') .. 'open'
            return
        endif

    # if we are already in the qf window, focus the previous one
    elseif we_are_in_qf && type == 'qf'
        wincmd p
        return

    # if we are already in the ll window, focus the associated window
    elseif we_are_in_qf && type == 'loc'
        let winid = getloclist(0, {'filewinid': 0})->get('filewinid', 0)
    endif

    win_gotoid(winid)
enddef

def Scratch(lines: list<string>) #{{{1
    # TODO: Improve the whole function after reading `~/wiki/vim/todo/scratch.md`.
    let tempfile = tempname()
    try
        exe 'sp ' .. tempfile
    # `:pedit` is forbidden from a Vim popup terminal window
    catch /^Vim\%((\a\+)\)\=:E994:/
        return s:Catch()
    endtry
    setline(0, lines)
    sil update
    # in case some line is too long for our vertical split
    setl wrap
    # for vim-window to not maximize the window when we focus it
    setl pvw
    nmap <buffer><nowait><silent> q <plug>(my_quit)
    wincmd p
enddef
