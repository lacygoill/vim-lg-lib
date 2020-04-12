" Interface {{{1
fu lg#map#save(keys, ...) abort "{{{2
    " `#save()` accepts a list of keys, or just a single key (in a string).
    if type(a:keys) != type([]) && type(a:keys) != type('') | return | endif

    " Which pitfall may I encounter when the pseudo-mode `''` is involved?{{{
    "
    " There could be a mismatch between the mode you've asked, and the one you get.
    "
    " Suppose you ask to save a mapping in `nvo` mode (via `''`).
    " But there is no such mapping.
    " However, there *is* a mapping in normal mode.
    " `maparg()` and `#save()` will save it, and `#restore()` will restore it.
    "
    " But if you  asked to save a  mapping in `nvo` mode,  it's probably because
    " you  intend to  install a  new mapping  in `nvo`  mode, which  will affect
    " several modes.
    " `#restore()`  will  restore the  normal  mode  mapping,  but it  will  not
    " "restore" the mappings in the other modes (i.e. it won't remove the mappings
    " you've installed in the other modes).
    "
    "     nno <c-q> <esc>
    "     let save = lg#map#save('<c-q>', '')
    "     noremap <c-q> <esc><esc>
    "     call lg#map#restore(save)
    "     map <c-q>
    "     n  <C-Q>       * <Esc>~
    "     ov <C-Q>       * <Esc><Esc>~
    "     ^^
    "     the C-q mappings in these modes should have been removed
    "
    " We don't deal with  this pitfall here because it would  make the code more
    " complex, and it can be easily fixed in your code:
    "
    "     nnoremap <c-q> <esc><esc>
    "     ^
    "     be more specific
    "}}}
    let mode = get(a:, '1', '')
    let wantlocal = get(a:, '2', v:false)
    let keys = type(a:keys) == type([]) ? a:keys : [a:keys]

    let save = []
    for key in keys
        let maparg = s:maparg(key, mode, wantlocal)
        let save += [maparg]
    endfor
    return save
endfu

" Usage:{{{
"
"     let my_global_mappings = lg#map#save(['key1', 'key2', ...], 'n')
"     let my_local_mappings  = lg#map#save(['key1', 'key2', ...], 'n', v:true)
"}}}

fu lg#map#restore(save) abort "{{{2
    " Why?{{{
    "
    " Sometimes, we may need to restore mappings stored in a variable which we
    " can't be sure will always exist.
    " In such  cases, it's  convenient to  use `get()` and  default to  an empty
    " list:
    "
    "     call lg#map#restore(get(g:, 'unsure_variable', []))
    "
    " To support this use case, we need to immediately return when we receive an
    " empty list, since there's nothing to restore.
    "}}}
    if empty(a:save) | return | endif

    for maparg in a:save
        " if the mapping was local to a buffer, check we're in the right one
        " If we are in the wrong buffer, why don't you temporarily load it?{{{
        "
        " Too many side-effects.
        "
        " You  need `:noa`  to suppress  autocmds, but  it doesn't  suppress
        " `CursorMoved`, probably because the latter is fired too late.
        " From `:h :noa`:
        "
        " >     Note that some autocommands are not triggered right away, but only later.
        " >     This specifically applies to |CursorMoved| and |TextChanged|.
        "
        " You also need to save and restore the alternate file.
        "
        " And you  need to save  and restore  some properties of  the buffer
        " where you re-install the mapping; like "was it unlisted?", "was it
        " unloaded?".
        "
        " And for  some reason,  some options  may be  reset in  the current
        " buffer (like `'cole'`).
        "
        " ---
        "
        " Besides, it adds a lot of complexity, for a dubious gain:
        "
        "     let [curbuf, origbuf] = [bufnr('%'), get(maparg, 'bufnr', 0)]
        "     if get(maparg, 'buffer', 0) && curbuf != origbuf
        "         if bufexists(origbuf)
        "             let altbuf = @#
        "             exe 'noa b '..origbuf
        "         endif
        "     endif
        "     " ...
        "     " restore local mapping
        "     " ...
        "     if exists('altbuf')
        "         noa exe 'b '..origbuf
        "         let @# = altbuf
        "     endif
        "}}}
        if s:not_in_right_buffer(maparg) | continue | endif

        let cmd = s:get_mapping_cmd(maparg)
        " if there was no mapping when `#save()` was invoked, there should be no
        " mapping after `#restore()` is invoked
        if has_key(maparg, 'unmapped')
            " `sil!` because there's no guarantee that the unmapped key has been
            " mapped to sth after being saved
            sil! exe cmd..' '..(maparg.buffer ? ' <buffer> ' : '')..maparg.lhs
        else
            " restore a saved mapping
            exe cmd
                \ ..(maparg.buffer  ? ' <buffer> ' : '')
                \ ..(maparg.expr    ? ' <expr>   ' : '')
                \ ..(maparg.nowait  ? ' <nowait> ' : '')
                \ ..(maparg.silent  ? ' <silent> ' : '')
                \ ..(!has('nvim') && maparg.script  ? ' <script> ' : '')
                \ ..maparg.lhs
                \ ..' '
                \ ..maparg.rhs
        endif
    endfor
endfu

" Usage:{{{
"
"     call lg#map#restore(save)
"
" `save` is a list obtained earlier by calling `lg#map#save()`.
" Its items are dictionaries describing saved mappings.
"}}}
"}}}1
" Core {{{1
fu s:maparg(name, mode, wantlocal) abort "{{{2
    let maparg = maparg(a:name, a:mode, 0, 1)

    " There are 6 cases to consider.{{{
    "
    " Parameter 1: we want a local mapping or a global one; 2 possibilities.
    "
    " Parameter 2: `maparg()` returns:
    "
    "    - an empty dictionary
    "    - the info about a global mapping
    "    - the info about a local mapping
    "
    " 3 possibilities.
    "
    " 2 x 3 = 6.
    "
    " Note that the 2 parameters are orthogonal.
    " We can ask for  a local mapping and get info about a  global one, and vice
    " versa.  That's  because there  is no  way to  specify to  `maparg()` which
    " scope we're interested in.
    "
    " ---
    "
    " 3 of those cases can be handled with the same code.
    " They all  have in common  that `maparg()`  doesn't give any  relevant info
    " (because the key is not mapped).
    "
    " 2 other cases can – again – be handled with the same code.
    " They both have in common that `maparg()` gives us the desired info.
    "
    " In the 1 remaining case, `maparg()` doesn't give any relevant info, but we
    " don't know whether the key is mapped.
    "
    " This is why,  in the end, we  only have to write 3  `if`, `elseif` blocks,
    " and not 6.
    "}}}
    " there is no relevant mapping
    if empty(maparg) || a:wantlocal && !s:islocal(maparg)
        " If there's no mapping, why do you still save this dictionary? {{{
        "
        " Suppose we have a key which is not mapped.
        " We save it with an empty dictionary.
        " Then, we map the key to something.
        " Finally,  we want  to restore  the key;  that means  deleting whatever
        " mapping may  now exist.  But to  be able to  unmap the key, we  need 3
        " information:
        "
        "    - is the mapping global or buffer-local (`<buffer>` argument)?
        "    - the lhs
        "    - the mode (normal, visual, ...)
        "
        " An empty dictionary doesn't contain any of this info.
        "}}}
        let maparg = {
            \ 'unmapped': v:true,
            \ 'lhs': a:name,
            "\ we want to be consistent with `maparg()` which would return a space for `nvo`
            \ 'mode': a:mode is# '' ? ' ' : a:mode,
            \ 'buffer': a:wantlocal,
            \ }

    " a local mapping is shadowing the global mapping we're interested in,
    " so we don't know whether there's a relevant mapping
    elseif !a:wantlocal && s:islocal(maparg)
        " remove the shadowing local mapping
        exe a:mode..'unmap <buffer> '..a:name
        let local_maparg = extend(deepcopy(maparg), {'bufnr': bufnr('%')})
        let maparg = s:maparg(a:name, a:mode, v:false)
        " restore the shadowing local mapping
        call lg#map#restore([local_maparg])

    " there is a relevant mapping
    else
        call extend(maparg, {
            "\ we don't want Vim to translate meta keys (e.g. `<M-b> → â`)
            \ 'lhs': a:name,
            "\ we want Vim to translate `<sid>`
            \ 'rhs': escape(maparg(a:name, a:mode), '|'),
            \ })
    endif

    if s:islocal(maparg)
        " Save the buffer number, so that we can check we're in the right buffer
        " when we want to restore the buffer-local mapping.
        call extend(maparg, {'bufnr': bufnr('%')})
    endif

    return maparg
endfu
"}}}1
" Util {{{1
fu s:islocal(maparg) abort "{{{2
    return get(a:maparg, 'buffer', 0)
endfu

fu s:not_in_right_buffer(maparg) abort "{{{2
    return s:islocal(a:maparg) && bufnr('%') != get(a:maparg, 'bufnr', 0)
endfu

fu s:get_mapping_cmd(maparg) abort "{{{2
    if has_key(a:maparg, 'unmapped')
        if a:maparg.mode is# '!'
            let cmd = 'unmap!'
        else
            let cmd = a:maparg.mode..'unmap'
        endif
    else
        if a:maparg.mode is# '!'
            let cmd = a:maparg.noremap ? 'noremap!' : 'map!'
        else
            let cmd = a:maparg.mode
            let cmd ..= a:maparg.noremap ? 'noremap' : 'map'
        endif
    endif
    return cmd
endfu

