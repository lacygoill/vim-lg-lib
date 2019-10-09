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

    " Why?{{{
    "
    " If we've saved a mapping for:
    "
    "    - a mode different than '', `lg#map#save()` will have returned a dictionary
    "    - the mode ''             , `lg#map#save()` will have returned a list
    "                                                                   of up to 3 dictionaries
    "}}}
    if type(a:map_save) == type({})
        call s:restore(a:map_save)
    elseif type(a:map_save) == type([])
        for a_map_save in a:map_save
            call s:restore(a_map_save)
        endfor
    endif
endfu

" Usage:{{{
"
"     call lg#map#restore(map_save)
"
" `map_save` is a dictionary obtained earlier by calling `lg#map#save()`.
" Its keys are the keys used in the mappings.
" Its values are the info about those mappings stored in sub-dictionaries.
"}}}

fu! s:restore(map_save) abort "{{{1
    for maparg in values(a:map_save)
        " If the mapping is local to a buffer, check we're in the right one.
        " Also make sure we have at least the 'lhs' key; just to be sure we
        " have received relevant information.
        if    get(maparg, 'buffer', 0) && bufnr('%') != get(maparg, 'bufnr', 0)
        \ || !has_key(maparg, 'lhs')
            continue
        endif

        " remove a possible mapping if it didn't exist when we tried to save it
        if has_key(maparg, 'unmapped')

            " `maparg.mode` could contain several modes (`nox` for example).
            " So we must split iterate over all characters inside.
            for c in split(maparg.mode, '\zs')
                sil! exe c..'unmap '..(maparg.buffer ? ' <buffer> ' : '')..maparg.lhs
            endfor

        " restore a saved mapping
        else
            for c in split(maparg.mode, '\zs')
                exe  c
                \ ..(maparg.noremap ? 'noremap   ' : 'map ')
                \ ..(maparg.buffer  ? ' <buffer> ' : '')
                \ ..(maparg.expr    ? ' <expr>   ' : '')
                \ ..(maparg.nowait  ? ' <nowait> ' : '')
                \ ..(maparg.silent  ? ' <silent> ' : '')
                \ ..maparg.lhs
                \ ..' '
                \ ..substitute(
                \              substitute(maparg.rhs, '<SID>', '<SNR>'..maparg.sid..'_', 'g'),
                \              '|', '<bar>', 'g')
            endfor
        endif
    endfor
endfu

fu! lg#map#save(mode, is_local, keys) abort "{{{1
    " The function accepts a list of keys, or just a single key (in a string).
    if type(a:keys) != type([]) && type(a:keys) != type('')
        return
    endif

    " If we pass the mode '', the function should interpret it as 'nvo',
    " like `maparg()` does.
    if a:mode is# ''
        let n_map_save = lg#map#save('n', a:is_local, a:keys)
        let x_map_save = lg#map#save('x', a:is_local, a:keys)
        let o_map_save = lg#map#save('o', a:is_local, a:keys)
        " And so, instead of returning a dictionary, it will return a list of up
        " to three dictionaries; one for each mode.
        return filter([n_map_save, x_map_save, o_map_save], {_,v -> !empty(v)})
    endif

    let keys = type(a:keys) == type([]) ? a:keys : [a:keys]

    let map_save = {}
    " get info about local mappings
    if a:is_local
        for a_key in keys
            " save info about the local mapping
            let maparg = maparg(a_key, a:mode, 0, 1)

            " If there is no local mapping, but there *is* a global mapping, ignore the latter.{{{
            "
            " By making `maparg` empty, we make sure that we will save some info
            " about the non-existing local mapping.
            " In particular, we  need the `unmapped` key to know  that the local
            " mapping does not exist.
            "}}}
            if has_key(maparg, 'buffer') && ! maparg.buffer
                let maparg = {}
            endif

            let map_save[a_key] = !empty(maparg)
                              \ ?        maparg
                              \ :        {
                              \            'unmapped' : 1,
                              \            'buffer'   : 1,
                              \            'lhs'      : a_key,
                              \            'mode'     : a:mode,
                              \          }
            " Save the  buffer number, so that  we can check we're  in the right
            " buffer when we want to restore a buffer-local mapping.
            call extend(map_save[a_key], {'bufnr': bufnr('%')})
        endfor

    " get info about global mappings
    else
        for a_key in keys
            " save info about the local mapping
            let local_maparg = maparg(a_key, a:mode, 0, 1)

            " If a key is used in a global mapping and a local one, by default,
            " `maparg()` only returns information about the local one.
            " We want to be able to get info about a global mapping even if a local
            " one shadows it.
            " To do that, we will temporarily remove the local mapping.
            sil! exe a:mode..'unmap <buffer> '..a_key

            " save info about the global one
            let maparg = maparg(a_key, a:mode, 0, 1)

            " make sure it's global
            if get(maparg, 'buffer', 0)
                continue
            endif

            let map_save[a_key] = !empty(maparg)
                              \ ?        maparg
                              \ :        {
                              \            'unmapped' : 1,
                              \            'buffer'   : 0,
                              \            'lhs'      : a_key,
                              \            'mode'     : a:mode,
                              \          }

            " If there's no mapping, why do we still save this dictionary: {{{
            "
            "     {
            "     \ 'unmapped' : 1,
            "     \ 'buffer'   : 0,
            "     \ 'lhs'      : a_key,
            "     \ 'mode'     : a:mode,
            "     \ }
            "
            " ?
            "
            " Suppose we have a key which is mapped to nothing.
            " We save it (with an empty dictionary).
            " It's possible that after the saving, the key is mapped to something.
            " Restoring this key means deleting whatever mapping may now exist.
            " But to be able to unmap the key, we need 3 information:
            "
            "    - is the mapping global or buffer-local (<buffer> argument)?
            "    - the lhs
            "    - the mode (normal, visual, …)
            "}}}

            " restore the local one
            call lg#map#restore({a_key : local_maparg})
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
