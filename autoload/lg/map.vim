if exists('g:autoloaded_lg#map')
    finish
endif
let g:autoloaded_lg#map = 1

" Init {{{1

let s:USE_FUNCTION_KEYS = !has('nvim') && !has('gui_running') && &t_TI !~# "\e[>4;2m"

if s:USE_FUNCTION_KEYS
    let s:KEY2FUNC = {
        \ 'a': '<f12>',
        \ 'b': '<f13>',
        \ 'c': '<f14>',
        \ 'd': '<f15>',
        \ 'e': '<f16>',
        \ 'f': '<f17>',
        \ 'g': '<f18>',
        \ 'h': '<f19>',
        \ 'i': '<f20>',
        \ 'j': '<f21>',
        \ 'k': '<f22>',
        \ 'l': '<f23>',
        \ 'm': '<f24>',
        \ 'n': '<f25>',
        \ 'o': '<f26>',
        \ 'p': '<f27>',
        \ 'q': '<f28>',
        \ 'r': '<f29>',
        \ 's': '<f30>',
        \ 't': '<f31>',
        \ 'u': '<f32>',
        \ 'v': '<f33>',
        \ 'w': '<f34>',
        \ 'x': '<f35>',
        \ 'y': '<f36>',
        \ 'z': '<f37>',
        \ 'A': '<s-f12>',
        \ 'B': '<s-f13>',
        \ 'C': '<s-f14>',
        \ 'D': '<s-f15>',
        \ 'E': '<s-f16>',
        \ 'F': '<s-f17>',
        \ 'G': '<s-f18>',
        \ 'H': '<s-f19>',
        \ 'I': '<s-f20>',
        \ 'J': '<s-f21>',
        \ 'K': '<s-f22>',
        \ 'L': '<s-f23>',
        \ 'M': '<s-f24>',
        \ 'N': '<s-f25>',
        \ 'O': '<s-f26>',
        \ 'P': '<s-f27>',
        \ 'Q': '<s-f28>',
        \ 'R': '<s-f29>',
        \ 'S': '<s-f30>',
        \ 'T': '<s-f31>',
        \ 'U': '<s-f32>',
        \ 'V': '<s-f33>',
        \ 'W': '<s-f34>',
        \ 'X': '<s-f35>',
        \ 'Y': '<s-f36>',
        \ 'Z': '<s-f37>',
        \ }

    fu s:set_keysyms() abort
        for [key, funckey] in items(s:KEY2FUNC)
            exe 'set '..funckey.."=\e"..key
        endfor
    endfu
    call s:set_keysyms()
endif

const s:FLAG2ARG = {
    \ 'S': '<script>',
    \ 'b': '<buffer>',
    \ 'e': '<expr>',
    \ 'n': '<nowait>',
    \ 's': '<silent>',
    \ 'u': '<unique>',
    \ }

" Interface {{{1
fu lg#map#meta(key, rhs, mode, flags) abort "{{{2
    exe (a:mode != '!' ? a:mode : '')..(a:flags =~# 'r' ? 'map' : 'noremap')..(a:mode == '!' ? '!' : '')
        \ ..' '..s:map_arguments(a:flags)
        \ ..' '..(s:USE_FUNCTION_KEYS ? s:KEY2FUNC[a:key] : '<m-'..a:key..'>')
        \ ..' '..a:rhs
endfu

fu lg#map#meta_notation(key) abort "{{{2
    if s:USE_FUNCTION_KEYS
        return eval('"\'..s:KEY2FUNC[a:key]..'"')
    else
        return eval('"\<m-'..a:key..'>"')
    endif
endfu

fu lg#map#save(keys, ...) abort "{{{2
    " `#save()` accepts a list of keys, or just a single key (in a string).
    if type(a:keys) != type([]) && type(a:keys) != type('') | return | endif

    " Which pitfall(s) may I encounter when the pseudo-mode `''` is involved?{{{
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
    "
    " ---
    "
    " There could be another type of mismatch.
    "
    " Suppose you ask to save a mapping in `n` mode.
    " But `maparg(...).mode` is `no`, and not `n`.
    "
    " `maparg()` and `#save()` save your mapping in `no` mode.
    " You change the mapping in `n` mode.
    " Later, you try to `#restore()` it; the latter function will reinstall your
    " mapping in `n` mode *and* in `o` mode.
    " You may find  the re-installation in `o` mode  unexpected and unnecessary;
    " but I don't think it's an issue.
    " There should  be no side-effect;  except for one: according  to `maparg()`
    " and `:map`, *before* you had 1 mapping  in `no` mode, but *now* you have 2
    " mappings, one in `n` mode, and another in `o` mode.
    "
    "     noremap <c-q> <esc>
    "     vunmap <c-q>
    "     map <c-q>
    "     no <C-Q>       * <Esc>~
    "
    "     let save = lg#map#save('<c-q>', 'n')
    "     call lg#map#restore(save)
    "     map <c-q>
    "     n  <C-Q>       * <Esc>~
    "     o  <C-Q>       * <Esc>~
    "
    " I don't consider that as an issue.
    " On the contrary, I prefer the second output, because `no` is not a real mode.
    "
    " ---
    "
    " I  think the  same pitfalls  could  apply to  `v` which  is a  pseudo-mode
    " matching the real modes `x` and `s`.
    "}}}
    let mode = get(a:, '1', '')
    let wantlocal = get(a:, '2', v:false)
    let keys = type(a:keys) == type([]) ? a:keys : [a:keys]

    let save = []
    for key in keys
        " This `for` loop is only necessary if you intend `#save()` to support multiple modes:{{{
        "
        "     let save = lg#map#save('<c-q>', 'nxo')
        "                                      ^^^
        "}}}
        for m in mode == '' ? [''] : split(mode, '\zs')
            let maparg = s:maparg(key, m, wantlocal)
            let save += [maparg]
        endfor
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

        " if there was no mapping when `#save()` was invoked, there should be no
        " mapping after `#restore()` is invoked
        if has_key(maparg, 'unmapped')
            let cmd = s:get_mapping_cmd(maparg)
            " `sil!` because there's no guarantee that the unmapped key has been
            " mapped to sth after being saved
            sil! exe cmd..' '..(maparg.buffer ? ' <buffer> ' : '')..maparg.lhs
        else
            " Even if you refactor `#save()` so that it only supports 1 mode, `#restore()` can still receive several.{{{
            "
            "     noremap <c-q> <esc>
            "     nunmap <c-q>
            "     echo maparg('<c-q>', '', 0, 1).mode
            "     ov~
            "     ^^
            "     2 modes
            "}}}
            for mode in split(maparg.mode, '\zs')
                " reinstall a saved mapping
                call s:reinstall(extend(maparg, {'mode': mode}))
            endfor
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

fu s:reinstall(maparg) abort "{{{2
    let cmd = s:get_mapping_cmd(a:maparg)
    exe cmd
        \ ..(a:maparg.buffer  ? ' <buffer> ' : '')
        \ ..(a:maparg.expr    ? ' <expr>   ' : '')
        \ ..(a:maparg.nowait  ? ' <nowait> ' : '')
        \ ..(a:maparg.silent  ? ' <silent> ' : '')
        \ ..(!has('nvim') && a:maparg.script  ? ' <script> ' : '')
        \ ..a:maparg.lhs
        \ ..' '
        \ ..a:maparg.rhs
endfu
"}}}1
" Util {{{1
fu s:map_arguments(flags) abort "{{{2
    return join(map(split(a:flags, '\zs'), 'get(s:FLAG2ARG, v:val, "")'))
endfu

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

