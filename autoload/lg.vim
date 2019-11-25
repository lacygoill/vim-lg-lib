fu lg#catch_error() abort "{{{1
    if get(g:, 'my_verbose_errors', 0)
        let func_name = matchstr(v:throwpoint, 'function \zs.\{-}\ze,')
        let line = matchstr(v:throwpoint, '\%(function \)\?.\{-}, \zsline \d\+')

        echohl ErrorMsg
        if !empty(func_name)
            echom 'Error detected while processing function '..func_name..':'
        else
            " the error comes from a (temporary?) file
            echom 'Error detected while processing '..matchstr(v:throwpoint, '.\{-}\ze,')..':'
        endif
        echohl LineNr
        echom line..':'
    endif

    echohl ErrorMsg
    " Even if you set “my_verbose_errors”, when this function will be called
    " from a function implementing an operator  (g@), only the last message will
    " be visible (i.e. v:exception).
    " But  it  doesn't matter. All  the  messages  have  been written  in  Vim's
    " log. So, `:WTF` will be able to show us where the error comes from.
    echom v:exception
    echohl NONE

    " It's important  to return  an empty string. Because  often, the  output of
    " this function will be executed or inserted. Check `vim-interactive-lists`,
    " and `vim-readline`.
    return ''
endfu

fu lg#man_k(pgm) abort "{{{1
    let cur_word = expand('<cword>')
    exe 'Man '..a:pgm

    try
        " populate location list
        noa exe 'lvim /\<\C'..cur_word..'\>/ %'
        " set its title
        call setloclist(0, [], 'a', { 'title': cur_word })

        sil! call lg#motion#repeatable#make#set_last_used(']l')
    catch
        try
            sil exe 'Man '..cur_word
        catch
            " If the word under the cursor is not present in any man page, quit.
            quit
            " FIXME:
            " If I hit `K` on a garbage word inside a shell script, the function
            " doesn't quit, because `:Man garbage_word` isn't considered an error.
            " If it was considered an error `:silent` wouldn't be enough to
            " hide the warning message. We would have to add a bang.
            " The problem comes from `man#open_page()` inside
            " ~/.vim/plugged/vim-man/autoload/man.vim
            "
            " When it receives an optional word as an argument, and there's no
            " manual page for it, the function calls `s:error()`. The latter
            " don't raise any exception. Maybe we could use `:throw`, although
            " I don't know how it works exactly. But then we would have errors
            " when we execute `:Man garbage_word` manually.
            "
            " Edit:
            " This whole code seems dubious. We  may silently ignore other valid
            " errors, because of these 2 nested try conditionals.
            " We should rethink this code.
        endtry
    endtry
endfu

fu lg#set_stl(ft, stl, ...) abort "{{{1
    if !has('nvim')
        if !a:0
            let &l:stl = a:stl
        else
            let &l:stl = '%!'..s:snr()..'set_stl('..string(a:stl)..', '..string(a:1)..')'
        endif
        return
    endif

    exe 'augroup '..a:ft..'_set_stl'
        au! * <buffer>
        if !a:0
            exe 'au WinEnter,WinLeave <buffer> call s:update_stl('..string(a:ft)..', '..string(a:stl)..')'
        else
            exe 'au WinEnter <buffer> call s:update_stl('..string(a:ft)..', '..string(a:stl)..')'
            exe 'au WinLeave <buffer> call s:update_stl('..string(a:ft)..', '..string(a:1)..')'
        endif
    augroup END
endfu

fu s:snr() abort
    return matchstr(expand('<sfile>'), '.*\zs<SNR>\d\+_')
endfu

fu s:set_stl(stl_focused, stl_unfocused) abort
    return a:stl_{g:statusline_winid == win_getid() ? '' : 'un'}focused
endfu

" Why don't you use a closure?{{{
"
" We  would  need to  overwrite  the  definition  of `s:update_stl`  every  time
" `lg#set_stl()` is invoked.
"
" But we may have an existing autocmd which relies on the current definition.
" MWE:
"
"     " source this
"     fu Func(arg)
"         exe 'augroup test_'..a:arg
"             au! * <buffer>
"             au WinEnter <buffer> call FuncA()
"         augroup END
"         fu! FuncA() closure
"             echom a:arg
"         endfu
"     endfu
"
"     " open 2 windows displaying `foo` and `bar`
"     " focus `foo`
"     :call Func('foo') " we expect 'foo' to be written on the cmdline every time we enter its window
"     " focus `bar`
"     :call Func('bar') " we expect 'bar' to be written on the cmdline every time we enter its window
"     " focus `foo`: 'bar' is displayed on the command-line; it should be 'foo'
"}}}
fu s:update_stl(ft, stl) abort
    if &ft is# a:ft
        let &l:stl = a:stl
    else
        exe 'au! '..a:ft..'_set_stl'
    endif
endfu

fu lg#termname() abort "{{{1
    if exists('$TMUX')
        return system('tmux display -p "#{client_termname}"')[:-2]
    else
        return $TERM
    endif
endfu

fu lg#win_execute(id, cmd, ...) abort "{{{1
    " TODO: Is this a bug?{{{
    "
    "     $ vim -Nu NONE -o /tmp/file{1..2} +'set wmh=0|call win_execute(win_getid(2), "wincmd _")'
    "
    " The current window is squashed to 0 lines, so the cursor is not visible anymore.
    " Note that  if you want  to maximize an  unfocused window (e.g.  the second
    " one), you can/should simply execute `:2resize`.
    "}}}
    let silent = a:0 ? [a:1] : []
    " `a:cmd` could contain a call to a script-local function.{{{
    "
    " When that happens, `s:` will be replaced by `<SNR>123_` where `123` is the
    " script id of the current file.
    " This is wrong; it should be  the id of the script where `lg#win_execute()`
    " was invoked; we need to resolve `s:` manually.
    "}}}
    let snr = matchstr(expand('<sfile>'), '\m\C.*\zs<SNR>\d\+_')
    let cmd = substitute(a:cmd, '\m\C\<s:\ze\h\+(', snr, 'g')
    if !has('nvim')
        call call('win_execute', [a:id, cmd] + silent)
    else
        " Make sure that the window layout is correct after running these commands:{{{
        "
        "     $ nvim +'helpg foobar'
        "
        " The height of the qf window should be 10.
        "
        " ---
        "
        "     $ nvim +'helpg foobar' +'wincmd t | sp'
        "
        " The top window should be squashed.
        "}}}

        " preserve current window
        let curwinid = win_getid()
        " preserve previous window
        let prevwinid = win_getid(winnr('#'))
        " preserve window size of target window
        let [tarheight, tarwidth, winrestcmd] = [winheight(a:id), winwidth(a:id), winrestcmd()]
        " Why `:noa`?{{{
        "
        " From `:h win_execute()`:
        "
        " > The  window will  temporarily be  made the  current window,  without
        " > triggering autocommands.
        "}}}
        noa call win_gotoid(a:id)
        let before = winrestcmd()
        " Why not `:noa`?{{{
        "
        " > When executing  {command} autocommands  will be triggered,  this may
        " > have unexpected side effects.  Use |:noautocmd| if needed.
        "}}}
        exe cmd
        let after = winrestcmd()
        " Rationale:{{{
        "
        " If `cmd` makes the layout change,  it means that the current layout is
        " desired, and  that's the  one we  should restore at  the end;  not the
        " original layout.
        "}}}
        if after isnot# before | let winrestcmd = after | endif
        " Rationale:{{{
        "
        "     $ nvim +'helpg foobar'
        "     :cbottom | wincmd k
        "
        " The view is altered in the qf  window (the value of `winline()` changes from 1
        " to 4); it should remain unchanged (it does in Vim).
        "
        " MWE:
        "
        "     $ vim -Nu NONE +'helpg foobar' +'helpc|cw10|norm! G' +'wincmd w|wincmd _|wincmd w|resize 10'
        "
        " This issue is a total mess.
        " Inconsistencies between Vim and Nvim, and inconsistencies in Vim itself.
        "
        " Try this:
        "
        "     $ vim -Nu NONE +'helpg foobar' +'helpc|cw10|norm! G' +'wincmd w'
        "     :wincmd _|wincmd w|resize 10
        "
        " Same result as in the first command before.
        " Now try this:
        "
        "     $ vim -Nu NONE +'helpg foobar' +'helpc|cw10|norm! G'
        "     :wincmd w|wincmd _|wincmd w|resize 10
        "
        " Different result (and yet same commands).
        "
        " Also, see this:
        "
        "     $ vim -Nu NONE +'helpg foobar' +'helpc|cw10|norm! G'
        "     :set wmh=0|wincmd w|wincmd _|2res10
        "
        "     $ nvim -Nu NONE +'helpg foobar' +'helpc|cw10|norm! G'
        "     :set wmh=0|wincmd w|wincmd _|2res10
        "
        " Same commands but different results.
        "}}}
        " Warning:{{{
        "
        " This is not the right fix:
        "
        "     $ nvim +'helpg foobar'
        "     :$
        "     " press `C-e` 5 times
        "     :wincmd k
        "
        " The view is altered in the qf window.
        "
        " I don't think there is a perfect solution; you have to choose the less
        " inconvenient of two pitfalls.
        " This pitfall seems less inconvenient than the previous one.
        "}}}
        let x = line('.') + (winheight(0)-winline())
        if x > line('$')
            exe 'norm! '..(x-line('$')).."\<c-y>"
        endif
        noa call win_gotoid(prevwinid)
        noa call win_gotoid(curwinid)
        " TODO: Should we remove the condition, and restore the layout unconditionally?
        " Rationale:{{{
        "
        " Suppose you have set `'wmh'` to 0.
        " As a result, the  other windows can be squashed to 0  lines, but only when
        " they are not focused.
        "
        " When focusing a window, its height will always be set to at least one line.
        " See `:h 'wmh`:
        "
        " > They will return to at least one line when they become active
        " > (since the cursor has to have somewhere to go.)
        "
        " IOW, the mere  fact of temporarily focusing a window  – even while the
        " autocmds are disabled – may increase its height by 1.
        "}}}
        noa exe winrestcmd
        if (&winminheight == 0 && tarheight != winheight(a:id))
        \ || (&winminwidth == 0 && tarwidth != winwidth(a:id))
            noa exe winrestcmd
        endif
    endif
endfu

fu lg#win_getid(arg) abort "{{{1
    if a:arg is# 'P'
        let winnr = index(map(range(1, winnr('$')), {_,v -> getwinvar(v, '&pvw')}), 1) + 1
        if winnr == 0 | return 0 | endif
        return win_getid(winnr)
    elseif a:arg is# '#'
        let winnr = winnr('#')
        return win_getid(winnr)
    endif
endfu

