if exists('g:autoloaded_my_lib')
    finish
endif
let g:autoloaded_my_lib = 1

" Functions {{{1
fu! my_lib#catch_error_in_op_function(type) abort "{{{2
    if get(g:, 'my_verbose_errors', 0)
        return 'echoerr '.string(v:exception.'    @@@ '.v:throwpoint)
    elseif index(['char', 'line', 'block'], a:type) >= 0
        echohl ErrorMsg
        echom v:exception.' | '.v:throwpoint
        echohl NONE
    else
        return 'return '.string('echoerr '.string(v:exception))
    endif
endfu

fu! my_lib#is_prime(n) abort "{{{2
    let n = a:n
    if type(n) !=# type(0) || n < 0
        echo 'Not a positive number'
        return ''
    endif

    " 1, 2 and 3 are special cases.
    " 2 and 3 are prime, 1 is not prime.

    if n == 2 || n == 3
        return 1
    elseif n == 1 || n % 2 == 0 || n % 3 == 0
        return 0

    " Why do we test whether `n` is divisible by 2 or 3?{{{
    "
    " `n` is not a prime    ⇒    its prime factor decomposition
    "                            includes a prime number
    "
    " All prime numbers follow the form `6k - 1` or `6k + 1`.
    " EXCEPT 2 and 3.
    "
    " Indeed, any number can be written in one of the following form:
    "
    "       • 6k        divisible by 6    not prime
    "       • 6k + 1                      could be prime
    "       • 6k + 2    "            2    not prime
    "       • 6k + 3    "            3    not prime
    "       • 6k + 4    "            2    not prime
    "       • 6k + 5                      could be prime
    "
    " So, for a number to be prime, it has to follow the form `6k ± 1`.
    " Any other form would mean it's divisible by 2 or 3.
    "
    " So, `n` is NOT a prime    ⇒    its prime factor decomposition
    "                                includes a `6k ± 1` number
    "                                OR 2 OR 3
    "
    " Therefore, we have to test 2 and 3 manually.
    " Later we'll test all the `6k ± 1` numbers.
"}}}
    endif

    " We'll begin testing if `n` is divisible by 5 (first `6k ± 1` number).
    let divisor = 5

    " `inc` is the increment we'll add to `divisor` at the end of each
    " iteration of the while loop.
    " The next divisor to test is 7, so, initially, the increment needs to be 2:
    "         7 = 5 + 2

    let inc = 2

    let sqrt = sqrt(n)
    while divisor <= sqrt

    " We could also write:     while i * i <= n{{{
    "
    " But then, each iteration of the loop would calculate `i*i`.
    " It's faster to just calculate the square root of `n` once and only
    " once, before the loop.
    "
    " Why do we stop testing after `sqrt`?
    " Suppose that `n` is not prime.
    " If all the factors in its prime factor decomposition are greater than
    " `√n` then their product is greater than `n` (which is of course
    " impossible).
    " Indeed, there's at least 2 factors in the decomposition of a non prime
    " number.
    " Therefore, if `n` is not prime, then its prime factor decomposition must
    " include at least one factor lower than `√n`:
    "
    "          n not prime             ⇒    n has a factor < √n
    "     ⇔    n has no factor < √n    ⇒    n is prime
"}}}
        if n % divisor == 0
            return 0
        endif

        let divisor += inc

        " The `6k ± 1` numbers are:
        "
        "         5, 7, 11, 13, 17, 19 …
        "
        " To generate them, we begin with 5, then add 2, then add 4, then add
        " 2, then add 4…
        " In other words, we have to increment `i` by 2 or 4, at the end of
        " every iteration of the while loop.
        "
        " How to code that?
        " Here's one way; the sum of 2 consecutive increments will always be
        " 6 (2+4 or 4+2):
        "
        "         inc_current + inc_next = 6
        "
        " Therefore:
        "
        "         inc_next = 6 - inc_current

        let inc = 6 - inc
    endwhile

    return 1
endfu

fu! my_lib#man_k(pgm) abort "{{{2
    let cur_word = expand('<cword>')
    let g:cur_word = deepcopy(cur_word)
    exe 'Man '.a:pgm

    try
        " populate location list
        exe 'lvim /\<\C'.cur_word.'\>/ %'
        " set its title
        call setloclist(0, [], 'a', { 'title': cur_word })

        " Hit `[L` and then `[l`, so that we can move across the matches with
        " `;` and `,`.
        sil! norm [L
        sil! norm [l
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
        endtry
    endtry
endfu

fu! my_lib#map_save(keys, mode, global) abort "{{{2
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
            " the code a little more readable inside `my_lib#map_restore()`.
            " Indeed, one can write:

            "     if has_key(mapping, 'unmapped') && !empty(mapping)
            "         …
            "     endif
            "
"}}}

            " restore the local one
            call my_lib#map_restore({l:key : buf_local_map})
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
"     let my_global_mappings = my_lib#map_save(['key1', 'key2', …], 'n', 1)
"     let my_local_mappings  = my_lib#map_save(['key1', 'key2', …], 'n', 0)
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
fu! my_lib#map_restore(mappings) abort "{{{2
    " Sometimes, we may need to restore mappings stored in a variable which we
    " can't be sure will always exist.
    " In such cases, it's convenient to use `get()` and default to an empty
    " list:
    "
    "     call my_lib#map_restore(get(g:, 'unsure_variable', []))
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
" `my_lib#map_restore()` is called, you're in the same buffer where
" `my_lib#map_save()` was originally called.
"
" If you aren't in the same buffer, you could install a buffer-local mapping
" inside a buffer where this mapping didn't exist before.
" It could cause unexpected behavior on the user's system.
"}}}
" Usage:{{{
"
"     call my_lib#map_restore(my_saved_mappings)
"
" `my_saved_mappings` is a dictionary obtained earlier by calling `my_lib#map_save()`.
" Its keys are the keys used in the mappings.
" Its values are the info about those mappings stored in sub-dictionaries.
"
" There's nothing special to pass to `my_lib#map_restore()`, no other
" argument, no wrapping inside a 3rd dictionary, or anything. Just this dictionary.
"}}}

fu! my_lib#matrix_transposition(...) abort "{{{2
    " This function expects several lists as arguments, with all the same length.
    " We could imagine the lists piled up, forming a matrix.
    " The function should return a single list of lists, whose items are the
    " columns of this table.
    " This is similar to what is called, in math, a transposition:
    "
    "         https://en.wikipedia.org/wiki/Transpose
    "
    " That is, reading the  lines in a transposed matrix is  the same as reading
    " the columns in the original one.


    " Make sure at least 2 lists were given as an argument.
    if a:0 < 2
        return -1
    endif

    " Check that all the arguments are lists and have the same length
    let length = len(a:1)
    for list in a:000
        if type(list) != type([]) || len(list) != length
            return -1
        endif
    endfor

    " Initialize a list of empty lists (whose number is length).
    " We can't use `repeat()`:
    "
    "         repeat([[]], length)
    "
    " … doesn't work as expected.
    " So we create a list of numbers with the same size (`range(length)`),
    " and then converts each number into [].
    let transposed = map(range(length), '[]')

    " Inside our table, we first iterate over lines (there're `a:0` lines),
    " then over columns (there're `length` columns).
    " With these nested for loops, we can reach all cells in the table:
    "
    "         a:000[i][j]    is the cell of coords [i,j]
    "
    " Imagine the upper-left corner is the origin of a coordinate system,
    "
    "         x axis goes down     = lines
    "         y axis goes right    = columns
    "
    " A cell must be added to a list of `transposed`. Which one?
    " A cell is in the j-th column / list of columns, so:    j
    for i in range(a:0)
        for j in range(length)
            call add(transposed[j], a:000[i][j])
        endfor
    endfor

    return transposed
endfu

fu! my_lib#max(numbers) abort "{{{2
    " reimplement `max()` and `min()` because the builtins don't handle floats
    if !len(a:numbers)
        return 0
    endif
    let max = a:numbers[0]
    for n in a:numbers[1:]
        if n > max
            let max = n
        endif
    endfor
    return max
endfu

fu! my_lib#min(numbers) abort "{{{2
    if !len(a:numbers)
        return 0
    endif
    let min = a:numbers[0]
    for n in a:numbers[1:]
        if n < min
            let min = n
        endif
    endfor
    return min
endfu

fu! my_lib#quit() abort "{{{2
    " If we are in the command-line window, we want to close the latter,
    " and return without doing anything else (save session).
    "
    "         ┌─ return ':' in a command-line window,
    "         │  nothing in a regular buffer
    "         │
    if !empty(getcmdwintype())
        close
        return ''
    endif

    if tabpagenr('$') == 1 && winnr('$') == 1
        " If there's only one tab page and only one window, we want to close
        " the session.
        qall

    " In neovim, we could also test the existence of `b:terminal_job_pid`.
    elseif &l:buftype == 'terminal'
        bw!

    else
        let was_loclist = get(b:, 'qf_is_loclist', 0)
        " if the window we're closing is associated to a ll window,
        " close the latter too
        sil! lclose

        " if we were already in a loclist window, then `:lclose` has closed it,
        " and there's nothing left to close
        if was_loclist
            return ''
        endif

        " same thing for preview window, but only in a help buffer outside of
        " preview winwow
        if &l:buftype ==# 'help' && !&previewwindow
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
            return 'echoerr '.string(v:exception)
        finally
            " if no session has been loaded so far, we don't want to see
            " `[S]` in the statusline;
            " and if a session was being tracked, we don't want to see `[S]`
            " but `[∞]`
            let v:this_session = session_save
            let &ssop = ssop_save
        endtry

        " We could also install an autocmd in our vimrc:
        "         au QuitPre * nested if &l:buftype != 'quickfix' | sil! lclose | endif
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
            return 'echoerr '.string(v:exception)
        endtry
    endif
    return ''
endfu

fu! my_lib#reg_save(names) abort "{{{2
    for name in a:names
        let prefix          = get(s:reg_translations, name, name)
        let s:{prefix}_save = [getreg(name), getregtype(name)]
    endfor
endfu

fu! my_lib#reg_restore(names) abort "{{{2
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

fu! my_lib#restore_closed_window(cnt) abort "{{{2
    if !exists('g:my_undo_sessions') || empty(g:my_undo_sessions)
        return ''
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
        return 'echoerr '.string(v:exception)
    finally
        " When we undo the closing of a window, we don't want the statusline to
        " tell us we've restored a session with the indicator [S].
        " It's a detail of implementation we're not interested in.
        "
        " Besides, if a session is being tracked, it would temporarily replace
        " `[∞]` with `[S]`, which would be a wrong indication.
        let v:this_session = session_save
    endtry
    return ''
endfu

" Variables "{{{1

let s:reg_translations = {
\                          '"': 'unnamed',
\                          '+': 'plus',
\                          '-': 'minus',
\                          '*': 'star',
\                          '/': 'slash',
\                        }
