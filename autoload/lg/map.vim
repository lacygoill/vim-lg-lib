fu! lg#map#restore(map_save) abort "{{{1
    " Why?{{{
    "
    " Sometimes, we may need to restore mappings stored in a variable which we
    " can't be sure will always exist.
    " In such cases, it's convenient to use `get()` and default to an empty
    " dictionary:
    "
    "     call lg#map#restore(get(g:, 'unsure_variable', {}))
    "
    " To support this use case, we need to immediately return when we receive
    " an empty dictionary, since there's nothing to restore.
    "}}}
    if empty(a:map_save)
        return
    endif

    for maparg in values(a:map_save)
        if !has_key(maparg, 'unmapped') && !empty(maparg)
            exe maparg.mode
            \. (maparg.noremap ? 'noremap   ' : 'map ')
            \. (maparg.buffer  ? ' <buffer> ' : '')
            \. (maparg.expr    ? ' <expr>   ' : '')
            \. (maparg.nowait  ? ' <nowait> ' : '')
            \. (maparg.silent  ? ' <silent> ' : '')
            \.  maparg.lhs
            \. ' '
            \. substitute(maparg.rhs, '<SID>', '<SNR>'.maparg.sid.'_', 'g')

        elseif has_key(maparg, 'unmapped')
            sil! exe maparg.mode.'unmap '.(maparg.buffer ? ' <buffer> ' : '').maparg.lhs
        endif
    endfor
endfu

" Warning:{{{
" Don't try to restore a buffer local mapping unless you're sure that, when
" `lg#map#restore()` is called, you're in the same buffer where
" `lg#map#save()` was originally called.
"
" If you aren't in the same buffer, you could install a buffer-local mapping
" inside a buffer where this mapping didn't exist before.
" It could cause unexpected behavior on the user's system.
"}}}
" Usage:{{{
"
"     call lg#map#restore(my_saved_mappings)
"
" `my_saved_mappings` is a dictionary obtained earlier by calling `lg#map#save()`.
" Its keys are the keys used in the mappings.
" Its values are the info about those mappings stored in sub-dictionaries.
"
" There's nothing special to pass to `lg#map#restore()`, no other
" argument, no wrapping inside a 3rd dictionary, or anything. Just this dictionary.
"}}}

fu! lg#map#save(mode, is_local, keys) abort "{{{1
    let map_save = {}

    " TRY to return info local mappings.
    " If they exist it will work, otherwise it will return info about global
    " mappings.
    if a:is_local
        for l:key in a:keys
            let maparg          =  maparg(l:key, a:mode, 0, 1)
            let map_save[l:key] = !empty(maparg)
            \?                           maparg
            \:                           {
            \                              'unmapped' : 1,
            \                              'buffer'   : 1,
            \                              'lhs'      : l:key,
            \                              'mode'     : a:mode,
            \                            }
        endfor

    else
        for l:key in a:keys
            let local_maparg = maparg(l:key, a:mode, 0, 1)

            " If a key is used in a global mapping and a local one, by default,
            " `maparg()` only returns information about the local one.
            " We want to be able to get info about a global mapping even if a local
            " one shadows it.
            " To do that, we will temporarily remove the local mapping.
            sil! exe a:mode.'unmap <buffer> '.l:key

            " save info about the global one
            let maparg          =  maparg(l:key, a:mode, 0, 1)
            let map_save[l:key] = !empty(maparg)
            \?                           maparg
            \:                           {
            \                              'unmapped' : 1,
            \                              'buffer'   : 0,
            \                              'lhs'      : l:key,
            \                              'mode'     : a:mode,
            \                            }

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
            " The 'unmapped' key is not necessary. I just find it can make
            " the code a little more readable inside `lg#map#restore()`.
            " Indeed, one can write:

            "     if !has_key(maparg, 'unmapped') && !empty(maparg)
            "         …
            "     endif
            "
"}}}

            " restore the local one
            call lg#map#restore({l:key : local_maparg})
        endfor
    endif

    return map_save
endfu

" Usage:{{{
"
"     let my_global_mappings = lg#map#save('n', 0, ['key1', 'key2', …])
"     let my_local_mappings  = lg#map#save('n', 1, ['key1', 'key2', …])
"}}}
" Output example: {{{

"     { '<left>':
"     \
"     \            { 'silent': 0,
"     \              'noremap': 1,
"     \              'lhs': '<Left>',
"     \              'mode': 'n',
"     \              'nowait': 0,
"     \              'expr': 0,
"     \              'sid': 7,
"     \              'rhs': ':echo ''foo''<cr>',
"     \              'buffer': 1 },
"     \
"     \ '<right>':
"     \
"     \            { 'silent': 0,
"     \              'noremap': 1,
"     \              'lhs': '<Right>',
"     \              'mode': 'n',
"     \              'nowait': 0,
"     \              'expr': 0,
"     \              'sid': 7,
"     \              'rhs': ':echo ''bar''<cr>',
"     \              'buffer': 1 },
"     \}
"
" }}}
