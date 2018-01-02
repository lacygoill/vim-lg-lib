" Functions {{{1
fu! lg#catch_error() abort "{{{2
    if get(g:, 'my_verbose_errors', 0)
        let func_name = matchstr(v:throwpoint, 'function \zs.\{-}\ze,')
        let line = matchstr(v:throwpoint, 'function .\{-}, \zsline \d\+')

        echohl ErrorMsg
        echom 'Error detected while processing function '.func_name.':'
        echohl LineNr
        echom line.':'
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

fu! lg#man_k(pgm) abort "{{{2
    let cur_word = expand('<cword>')
    exe 'Man '.a:pgm

    try
        " populate location list
        exe 'lvim /\<\C'.cur_word.'\>/ %'
        " set its title
        call setloclist(0, [], 'a', { 'title': cur_word })

        let g:motion_to_repeat = ']l'
    catch
        try
            sil exe 'Man '.cur_word
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

fu! lg#map_save(keys, mode, global) abort "{{{2
    let mappings = {}

    " If a key is used in a global mapping and a local one, by default,
    " `maparg()` only returns information about the local one.
    " We want to be able to get info about a global mapping even if a local
    " one shadows it.
    " To do that, we will temporarily unmap the local mapping.

    if a:global
        for l:key in a:keys
            let buf_local_map = maparg(l:key, a:mode, 0, 1)

            " temporarily unmap the local mapping
            sil! exe a:mode.'unmap <buffer> '.l:key

            " save info about the global one
            let map_info        = maparg(l:key, a:mode, 0, 1)
            let mappings[l:key] =   !empty(map_info)
            \                     ?     map_info
            \                     :     {
            \                             'unmapped' : 1,
            \                             'buffer'   : 0,
            \                             'lhs'      : l:key,
            \                             'mode'     : a:mode,
            \                           }

            " If there's no mapping, why do we still save this dictionary: {{{

            "     {
            "     \ 'unmapped' : 1,
            "     \ 'buffer'   : 0,
            "     \ 'lhs'      : l:key,
            "     \ 'mode'     : a:mode,
            "     \ }

            " …?
            " Suppose we have a key which is mapped to nothing.
            " We save it (with an empty dictionary).
            " It's possible that after the saving, the key is mapped to something.
            " Restoring this key means deleting whatever mapping may now exist.
            " But to be able to unmap the key, we need 3 information:
            "
            "         • is the mapping global or buffer-local (<buffer> argument)?
            "         • the lhs
            "         • the mode (normal, visual, …)
            "
            " The `'unmapped'` key is not necessary. I just find it can make
            " the code a little more readable inside `lg#map_restore()`.
            " Indeed, one can write:

            "     if has_key(mapping, 'unmapped') && !empty(mapping)
            "         …
            "     endif
            "
"}}}

            " restore the local one
            call lg#map_restore({l:key : buf_local_map})
        endfor

    " TRY to return info local mappings.
    " If they exist it will work, otherwise it will return info about global
    " mappings.
    else
        for l:key in a:keys
            let map_info        = maparg(l:key, a:mode, 0, 1)
            let mappings[l:key] =   !empty(map_info)
            \                     ?     map_info
            \                     :     {
            \                             'unmapped' : 1,
            \                             'buffer'   : 1,
            \                             'lhs'      : l:key,
            \                             'mode'     : a:mode,
            \                           }
        endfor
    endif

    return mappings
endfu

" Usage:{{{
"
"     let my_global_mappings = lg#map_save(['key1', 'key2', …], 'n', 1)
"     let my_local_mappings  = lg#map_save(['key1', 'key2', …], 'n', 0)
"}}}
" Output example: {{{

"     { '<left>' :
"                \
"                \ {'silent': 0,
"                \ 'noremap': 1,
"                \ 'lhs': '<Left>',
"                \ 'mode': 'n',
"                \ 'nowait': 0,
"                \ 'expr': 0,
"                \ 'sid': 7,
"                \ 'rhs': ':echo ''foo''<cr>',
"                \ 'buffer': 1},
"                \
"     \ '<right>':
"                \
"                \ { 'silent': 0,
"                \ 'noremap': 1,
"                \ 'lhs': '<Right>',
"                \ 'mode': 'n',
"                \ 'nowait': 0,
"                \ 'expr': 0,
"                \ 'sid': 7,
"                \ 'rhs': ':echo ''bar''<cr>',
"                \ 'buffer': 1,
"                \ },
"                \}
"
" }}}
fu! lg#map_restore(mappings) abort "{{{2
    " Sometimes, we may need to restore mappings stored in a variable which we
    " can't be sure will always exist.
    " In such cases, it's convenient to use `get()` and default to an empty
    " list:
    "
    "     call lg#map_restore(get(g:, 'unsure_variable', []))
    "
    " To support this use case, we need to immediately return when we receive
    " an empty list, since there's nothing to restore.
    if empty(a:mappings)
        return
    endif

    for mapping in values(a:mappings)
        if !has_key(mapping, 'unmapped') && !empty(mapping)
            exe     mapping.mode
               \ . (mapping.noremap ? 'noremap   ' : 'map ')
               \ . (mapping.buffer  ? ' <buffer> ' : '')
               \ . (mapping.expr    ? ' <expr>   ' : '')
               \ . (mapping.nowait  ? ' <nowait> ' : '')
               \ . (mapping.silent  ? ' <silent> ' : '')
               \ .  mapping.lhs
               \ . ' '
               \ . substitute(mapping.rhs, '<SID>', '<SNR>'.mapping.sid.'_', 'g')

        elseif has_key(mapping, 'unmapped')
            sil! exe mapping.mode.'unmap '
                                \ .(mapping.buffer ? ' <buffer> ' : '')
                                \ . mapping.lhs
        endif
    endfor
endfu

" Warning:{{{
" Don't try to restore a buffer local mapping unless you're sure that, when
" `lg#map_restore()` is called, you're in the same buffer where
" `lg#map_save()` was originally called.
"
" If you aren't in the same buffer, you could install a buffer-local mapping
" inside a buffer where this mapping didn't exist before.
" It could cause unexpected behavior on the user's system.
"}}}
" Usage:{{{
"
"     call lg#map_restore(my_saved_mappings)
"
" `my_saved_mappings` is a dictionary obtained earlier by calling `lg#map_save()`.
" Its keys are the keys used in the mappings.
" Its values are the info about those mappings stored in sub-dictionaries.
"
" There's nothing special to pass to `lg#map_restore()`, no other
" argument, no wrapping inside a 3rd dictionary, or anything. Just this dictionary.
"}}}

fu! lg#quit() abort "{{{2
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
    elseif &bt == 'terminal'
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
        if &bt ==# 'help' && !&previewwindow
            pclose
        endif

        " create a new temporary file for the session we're going to save
        let g:my_undo_sessions = get(g:, 'my_undo_sessions', []) + [ tempname() ]

        try
            let session_save = v:this_session

            " don't save cwd
            let ssop_save = &ssop
            set ssop-=curdir

            exe 'mksession! '.g:my_undo_sessions[-1]
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
        "         au QuitPre * nested if &bt != 'quickfix' | sil! lclose | endif
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

fu! lg#reg_save(names) abort "{{{2
    for name in a:names
        let prefix          = get(s:reg_translations, name, name)
        let s:{prefix}_save = [getreg(name), getregtype(name)]
    endfor
endfu

fu! lg#reg_restore(names) abort "{{{2
    for name in a:names
        let prefix   = get(s:reg_translations, name, name)
        let contents = s:{prefix}_save[0]
        let type     = s:{prefix}_save[1]

        " FIXME: how to restore `0` {{{

        " When we restore use `setreg()` or `:let`, we can't make
        " a distinction between the unnamed and copy registers.
        " IOW, whatever we do to one of them, we do it to the other.
        "
        " Why are they synchronized with `setreg()` and `:let`?
        " They aren't in normal mode. If I copy some text, they will be
        " identical. But if I delete some other text just afterwards, they
        " will be different.
        "
        " I could understand the synchronization in one direction:
        "
        "     change @0    →    change @"
        "
        " … because one could argue that the unnamed register points to the
        " last changed register. So, when we change the contents of the copy
        " register, the unnamed points to the latter. OK, why not.
        " But I can't understand in the other direction:
        "
        "     change @"    →    change @0
        "
        " If I execute:
        "
        "     :call setreg('"', 'unnamed')
        "
        " … why does the copy register receives the same contents?
        "
        " This cause a problem for all functions (operators) which need to
        " temporarily copy some text, want to restore the unnamed register
        " as well as the copy register to whatever old values they had, and
        " those 2 registers are different at the time the function was
        " invoked.
        "
        " That's why, at the moment, I don't try to restore the copy register
        " in ANY operator function. I simply CAN'T.
"}}}

        call setreg(name, contents, type)
    endfor
endfu

fu! lg#restore_closed_window(cnt) abort "{{{2
    if !exists('g:my_undo_sessions') || empty(g:my_undo_sessions)
        return
    endif

    sil! tabdo tabclose
    sil! windo close

    try
        let session_save = v:this_session
        "                                     ┌─ handle the case where we hit a too big number
        "                                     │
        let session_file = g:my_undo_sessions[max([ -a:cnt, -len(g:my_undo_sessions) ])]

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

        exe 'so '.session_file

        " if we gave a count to restore several windows, we probably    ┐
        " want to reset the stack of sessions, otherwise the next time  │
        " we would hit `{number} leader u`, if `{number}` is too big    │
        " we would end up in a weird old session we don't remember      │
        "                                                               │
        " I'm still not sure it's the right thing to do, because        │
        " it prevents us from hitting `leader u` once again if          │
        " `{number}` was too small; time will tell                      │
        let g:my_undo_sessions = a:cnt == 1 ? g:my_undo_sessions[:-2] : []

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

" Variables "{{{1

let s:reg_translations = {
\                          '"': 'unnamed',
\                          '+': 'plus',
\                          '-': 'minus',
\                          '*': 'star',
\                          '/': 'slash',
\                        }
