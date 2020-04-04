" Interface {{{1
fu lg#map#save(keys, ...) abort "{{{2
    " The function accepts a list of keys, or just a single key (in a string).
    if type(a:keys) != type([]) && type(a:keys) != type('') | return | endif

    let mode = get(a:, '1', 'n')
    let islocal = get(a:, '2', v:false)

    " If we pass the mode `''`, we want the function to interpret it as `'nvo'`,
    " to be consistent with `maparg()`.
    if mode is# ''
        " TODO: Wait.  Is it correct?{{{
        "
        " Shouldn't we just pass `''` and let `maparg()` do its job normally?
        " What if we pass  `''`, don't have any mapping in  `nvo` mode, but have
        " one in  `x` mode?  How does  `maparg()` react?  How does  our function
        " react?  How should it react?
        "
        " ---
        "
        " Vimgrep `lg#map#save()` and check whether we've used `''` often.
        " Btw, one  of the match is  in `vim-draw`; there is  long comment there
        " which you need to re-read/fix/update.
        "
        "     ~/.vim/plugged/vim-draw/autoload/draw.vim:378
        "}}}
        let n_map_save = lg#map#save(a:keys, 'n', islocal)
        let x_map_save = lg#map#save(a:keys, 'x', islocal)
        let o_map_save = lg#map#save(a:keys, 'o', islocal)
        " And so, instead of returning a dictionary, it will return a list of up
        " to three dictionaries; one for each mode.
        return filter([n_map_save, x_map_save, o_map_save], {_,v -> !empty(v)})
    endif

    let keys = type(a:keys) == type([]) ? a:keys : [a:keys]

    let map_save = {}
    " get info about local mappings
    if islocal
        for a_key in keys
            " save info about the local mapping
            let maparg = s:maparg(a_key, mode)

            " If there is no local mapping, but there *is* a global mapping, ignore the latter.{{{
            "
            " By making `maparg` empty, we make sure that we will save some info
            " about the non-existing local mapping.
            " In particular, we  need the `unmapped` key to know  that the local
            " mapping does not exist.
            "}}}
            if has_key(maparg, 'buffer') && !maparg.buffer
                let maparg = {}
            endif

            let map_save[a_key] = s:mapsave(maparg, a_key, mode, v:true)

            " Save the  buffer number, so that  we can check we're  in the right
            " buffer when we want to restore a buffer-local mapping.
            call extend(map_save[a_key], {'bufnr': bufnr('%')})
        endfor

    " get info about global mappings
    else
        for a_key in keys
            " save info about the local mapping
            let local_maparg = s:maparg(a_key, mode)

            " If a key is used in a global mapping and a local one, by default,
            " `maparg()` only returns information about the local one.
            " We want to be able to get info about a global mapping even if a local
            " one shadows it.
            " To do that, we will temporarily remove the local mapping.
            sil! exe mode..'unmap <buffer> '..a_key

            " save info about the global one
            let maparg = s:maparg(a_key, mode)

            " make sure it's global
            if get(maparg, 'buffer', 0) | continue | endif

            let map_save[a_key] = s:mapsave(maparg, a_key, mode, v:false)

            " restore the local one
            call lg#map#restore({a_key : local_maparg})
        endfor
    endif

    return map_save
endfu

" Usage:{{{
"
"     let my_global_mappings = lg#map#save(['key1', 'key2', ...], 'n')
"     let my_local_mappings  = lg#map#save(['key1', 'key2', ...], 'n', v:true)
"}}}

fu lg#map#restore(map_save) abort "{{{2
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
    if empty(a:map_save) | return | endif

    " Why?{{{
    "
    " If we've saved a mapping for:
    "
    "    - a mode different than `''`, `lg#map#save()` will have returned a dictionary
    "    - the mode `''`             , `lg#map#save()` will have returned a list of up to 3 dictionaries
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

fu s:restore(map_save) abort
    for maparg in values(a:map_save)
        " If the mapping is local to a buffer, check we're in the right one.
        " Also make sure we have at least the `lhs` key; just to be sure we have
        " received relevant information.
        if get(maparg, 'buffer', 0) && bufnr('%') != get(maparg, 'bufnr', 0)
        \ || !has_key(maparg, 'lhs')
            " TODO: If we are in the wrong buffer, maybe we could temporarily load it?{{{
            "
            " If you  do make sure  to not trigger  events (`:noa`), and  to not
            " alter the previous  file (`@#`). Also, check  its existence before
            " trying to load it.
            "}}}
            continue
        endif

        " remove a possible mapping if it didn't exist when we tried to save it
        if has_key(maparg, 'unmapped')
            " `maparg.mode` could contain several modes (`nox` for example);  we must iterate over them
            for c in split(maparg.mode, '\zs')
                sil! exe c..'unmap '..(maparg.buffer ? ' <buffer> ' : '')..maparg.lhs
            endfor
        else
            for c in split(maparg.mode, '\zs')
                " restore a saved mapping
                exe c
                    \ ..(maparg.noremap ? 'noremap   ' : 'map ')
                    \ ..(maparg.buffer  ? ' <buffer> ' : '')
                    \ ..(maparg.expr    ? ' <expr>   ' : '')
                    \ ..(maparg.nowait  ? ' <nowait> ' : '')
                    \ ..(maparg.silent  ? ' <silent> ' : '')
                    \ ..maparg.lhs
                    \ ..' '
                    \ ..maparg.rhs
            endfor
        endif
    endfor
endfu
"}}}1
" Core {{{1
fu s:maparg(name, mode) abort "{{{2
    let maparg = maparg(a:name, a:mode, 0, 1)
    call extend(maparg, {'rhs': escape(maparg(a:name, a:mode), '|')})
    return maparg
endfu

fu s:mapsave(maparg, key, mode, islocal) abort "{{{2
    if empty(a:maparg)
        " If there's no mapping, why do we still save this dictionary? {{{
        "
        " Suppose we have a key which is mapped to nothing.
        " We save it (with an empty dictionary).
        " It's possible that after the saving, the key is mapped to something.
        " Restoring this key means deleting whatever mapping may now exist.
        " But to be able to unmap the key, we need 3 information:
        "
        "    - is the mapping global or buffer-local (`<buffer>` argument)?
        "    - the lhs
        "    - the mode (normal, visual, ...)
        "}}}
        return {
            \ 'unmapped': v:true,
            \ 'buffer': a:islocal,
            \ 'lhs': a:key,
            \ 'mode': a:mode,
            \ }
    else
        return a:maparg
    endif
endfu

