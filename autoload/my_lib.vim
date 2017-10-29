if exists('g:autoloaded_my_lib')
    finish
endif
let g:autoloaded_my_lib = 1

" Functions {{{1
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
" Variables "{{{1

let s:reg_translations = {
\                          '"': 'unnamed',
\                          '+': 'plus',
\                          '-': 'minus',
\                          '*': 'star',
\                          '/': 'slash',
\                        }
