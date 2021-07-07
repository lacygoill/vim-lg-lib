vim9script

# Init {{{1

# TODO: Remove these lines once you find a fix for this issue:
# https://github.com/vim/vim/issues/5951
&t_TI = ''
&t_TE = ''

const IS_MODIFYOTHERKEYS_ENABLED: bool = &t_TI =~ "\<Esc>\\[>4;[12]m"
# We need to run `:execute "set <F13>=\<Esc>b"` instead of `:execute "set <M-B>=\<Esc>b"` because:{{{
#
#    - we want to be able to insert some accented characters
#    - if we hit one of them by accident, we don't want to trigger some custom meta mapping
#}}}
# But not in a terminal where `modifyOtherKeys` is enabled, nor in the GUI.
# No need to, everything works fine there.
const USE_FUNCTION_KEYS: bool = !has('gui_running') && !IS_MODIFYOTHERKEYS_ENABLED

export var KEY2FUNC: dict<string>

if USE_FUNCTION_KEYS
    KEY2FUNC = {
        a: '<F12>',
        b: '<F13>',
        c: '<F14>',
        d: '<F15>',
        e: '<F16>',
        f: '<F17>',
        g: '<F18>',
        h: '<F19>',
        i: '<F20>',
        j: '<F21>',
        k: '<F22>',
        l: '<F23>',
        m: '<F24>',
        n: '<F25>',
        o: '<F26>',
        p: '<F27>',
        q: '<F28>',
        r: '<F29>',
        s: '<F30>',
        t: '<F31>',
        u: '<F32>',
        v: '<F33>',
        w: '<F34>',
        x: '<F35>',
        y: '<F36>',
        z: '<F37>',
        A: '<S-F12>',
        B: '<S-F13>',
        C: '<S-F14>',
        D: '<S-F15>',
        E: '<S-F16>',
        F: '<S-F17>',
        G: '<S-F18>',
        H: '<S-F19>',
        I: '<S-F20>',
        J: '<S-F21>',
        K: '<S-F22>',
        L: '<S-F23>',
        M: '<S-F24>',
        N: '<S-F25>',
        # Do *not* add 'O', nor 'P'.{{{
        #
        #     'O': '<S-F26>',
        #
        # It would cause a bug in xterm:
        #
        #     # start an xterm terminal
        #     $ vim -Nu NONE -S <(cat <<'EOF'
        #         set t_RV= t_TE= t_TI=
        #         execute "set <S-F26>=\<Esc>O"
        #         cnoremap <S-F26> <Nop>
        #         cnoremap <F3> abc
        #     EOF
        #     )
        #
        #     # press:     : <F3>
        #     # expected:  'abc' is written on the command-line
        #     # actual:    'R' is written on the command-line
        #
        # ---
        #
        # At  least, don't  do  it  until you  can  stop  clearing `'t_TI'`  and
        # `'t_TE'` in xterm (for the moment, we have to because of another bug).
        #
        # ---
        #
        # Similar issue with the `P` character:
        #
        #     vim -Nu NONE --cmd 'execute "set <S-F27>=\<Esc>P"' \
        #                  --cmd 'let [&t_TI, &t_TE] = ["", ""]' \
        #                  --cmd 'nnoremap <Space>q :quitall!<CR>'
        #
        # Here, *sometimes*, the mapping  is unexpectedly triggered, causing Vim
        # to quit right after starting up, which is very confusing.
        #}}}
        Q: '<S-F28>',
        R: '<S-F29>',
        S: '<S-F30>',
        T: '<S-F31>',
        U: '<S-F32>',
        V: '<S-F33>',
        W: '<S-F34>',
        X: '<S-F35>',
        Y: '<S-F36>',
        Z: '<S-F37>',
    }

    def SetKeysyms()
        for [key: string, funckey: string] in items(KEY2FUNC)
            execute 'set ' .. funckey .. "=\<Esc>" .. key
        endfor
    enddef
    # We don't really need to delay until `VimEnter` for the moment.{{{
    #
    # But it could be necessary in the future if you want to run this code for the GUI.
    # Indeed, in  the GUI, if  you set the  keysyms during the  startup process,
    # they are somehow cleared at the end.
    #}}}
    autocmd VimEnter * SetKeysyms()

    # Fix readline commands in a terminal buffer.{{{
    #
    # When you press `M-b`, the terminal writes `Esc` + `b` in the typeahead buffer.
    # And  since  we're going  to  run  `:set  <F13>=^[b`, Vim  translates  this
    # sequence into `<F13>` which – internally – is encoded as `<80>F3` (`:echo "\<F13>"`).
    #
    # So, Vim sends `<80>F3` to the shell running in the terminal buffer instead
    # of `Esc` + `b`.
    # This breaks all  readline commands; to fix this, we  use Terminal-Job mappings
    # to make  Vim relay the  correct sequences to the  shell (the ones  it received
    # from the terminal, unchanged).
    #
    # https://github.com/vim/vim/issues/2397
    #
    # ---
    #
    # The issue affects the GUI.
    # The issue affects Vim iff one of these statements is true:
    #
    #    - you run `:set <xxx>=^[b` (`xxx` being anything: `<M-B>`, `<F13>`, ...)
    #    - you use `:help modifyOtherKeys`
    #}}}
    def FixMetaReadline()
        for [key: string, funckey: string] in items(KEY2FUNC)
            execute 'tnoremap ' .. funckey .. ' <Esc>' .. key
        endfor
    enddef
    FixMetaReadline()

    def NopUnusedMetaChords()
        for funckey: string in values(KEY2FUNC)
            # we don't  want `<F37>` to  be inserted into  the buffer or  on the
            # command-line, if we press `<M-Z>` and nothing is bound to it
            if maparg(funckey, 'i')->empty()
                execute 'inoremap ' .. funckey .. ' <Nop>'
            endif
            if maparg(funckey, 'c')->empty()
                execute 'cnoremap ' .. funckey .. ' <Nop>'
            endif
        endfor
    enddef
    # delay until `VimEnter` so that we can  check which meta keys have not been
    # mapped to anything in the end
    autocmd VimEnter * NopUnusedMetaChords()

elseif IS_MODIFYOTHERKEYS_ENABLED || has('gui_running')
    # Same issue as previously.{{{
    #
    # When  you press  `M-b`,  the terminal  sends some  special  sequence in  a
    # terminal where modifyOtherKeys is enabled, or `Esc` + `b` in the GUI.
    #
    # In any case, Vim encodes the sequence  into `â`, which is then sent to the
    # shell.  Again, this  breaks all readline commands, and  again the solution
    # is to install a bunch of Terminal-Job  mode mappings so that Vim sends the
    # right sequences to the shell.
    #}}}
    def FixMetaReadline()
        for key: string in (
            range(char2nr('a'), char2nr('z'))
          + range(char2nr('A'), char2nr('Z'))
        )->mapnew((_, v: number): string => nr2char(v))
            execute 'tnoremap <M-' .. key .. '> <Esc>' .. key
        endfor
    enddef
    FixMetaReadline()

    def NopUnusedMetaChords()
        var lhs: string
        for key: string in (
            range(char2nr('a'), char2nr('z'))
          + range(char2nr('A'), char2nr('Z'))
        )->mapnew((_, v: number): string => nr2char(v))
            if toupper(key) == key
                lhs = '<M-S-' .. key .. '>'
            else
                lhs = '<M-' .. key .. '>'
            endif
            # we don't want  `ú` (!= `ù`) to  be inserted into the  buffer or on
            # the command-line, if we press `<M-z>` and nothing is bound to it
            if maparg(lhs, 'i')->empty()
                execute 'inoremap ' .. lhs .. ' <Nop>'
            endif
            if maparg(lhs, 'c')->empty()
                execute 'cnoremap ' .. lhs .. ' <Nop>'
            endif
        endfor
    enddef
    autocmd VimEnter * NopUnusedMetaChords()
endif

# Interface {{{1
export def MapMeta(mapping: string) #{{{2
    try
        var fixed_mapping: string = mapping
        if USE_FUNCTION_KEYS
            fixed_mapping = mapping
                ->substitute('\c<M-\(\a\)>', ((m) => KEY2FUNC[m[1]->tolower()]), 'g')
                ->substitute('\c<M-S-\(\a\)>', ((m) => KEY2FUNC[m[1]->toupper()]), 'g')
        endif
        execute fixed_mapping
    catch /^Vim\%((\a\+)\)\=:E227:/
        echohl ErrorMsg
        unsilent echomsg v:exception
        echohl NONE
    endtry
enddef

export def MapMetaChord(key: string, symbolic = false): string #{{{2
    # give us a symbolic notation (e.g. `<M-A>`)
    if symbolic
        # terminal *not* supporting modifyOtherKeys
        if USE_FUNCTION_KEYS
            return KEY2FUNC[key]
        # GUI or terminal supporting modifyOtherKeys
        else
            if key == tolower(key)
                return '<M-' .. key .. '>'
            else
                return '<M-S-' .. key .. '>'
            endif
        endif

    # give us a byte sequence (e.g. `à` or `<80>F3`)
    else
        if USE_FUNCTION_KEYS
            return eval('"\' .. KEY2FUNC[key] .. '"')
        else
            if key == tolower(key)
                return eval('"\<M-' .. key .. '>"')
            else
                return eval('"\<M-S-' .. key .. '>"')
            endif
        endif
    endif
enddef

export def MapSave( #{{{2
    arg_keys: any,
    mode = '',
    wantlocal = false
): list<dict<any>>

    if typename(arg_keys) !~ '^list' && typename(arg_keys) != 'string'
        return []
    endif
    # `#save()` accepts a list of keys, or just a single key (in a string).

    # Which pitfall(s) may I encounter when the pseudo-mode `''` is involved?{{{
    #
    # There could be a mismatch between the mode you've asked, and the one you get.
    #
    # Suppose you ask to save a mapping in `nvo` mode (via `''`).
    # But there is no such mapping.
    # However, there *is* a mapping in normal mode.
    # `maparg()` and `#save()` will save it, and `#restore()` will restore it.
    #
    # But if you  asked to save a  mapping in `nvo` mode,  it's probably because
    # you  intend to  install a  new mapping  in `nvo`  mode, which  will affect
    # several modes.
    # `#restore()`  will  restore the  normal  mode  mapping,  but it  will  not
    # "restore" the mappings in the other modes (i.e. it won't remove the mappings
    # you've installed in the other modes).
    #
    #     nnoremap <C-Q> <Esc>
    #     var save: list<dict<any>> = MapSave('<C-Q>', '')
    #     noremap <C-Q> <Esc><Esc>
    #     MapRestore(save)
    #     map <C-Q>
    #     n  <C-Q>       * <Esc>˜
    #     ov <C-Q>       * <Esc><Esc>˜
    #     ^^
    #     the C-q mappings in these modes should have been removed
    #
    # We don't deal with  this pitfall here because it would  make the code more
    # complex, and it can be easily fixed in your code:
    #
    #     nnoremap <C-Q> <Esc><Esc>
    #     ^
    #     be more specific
    #
    # ---
    #
    # There could be another type of mismatch.
    #
    # Suppose you ask to save a mapping in `n` mode.
    # But `maparg(...)[mode]` is `no`, and not `n`.
    #
    # `maparg()` and `#save()` save your mapping in `no` mode.
    # You change the mapping in `n` mode.
    # Later, you try to `#restore()` it; the latter function will reinstall your
    # mapping in `n` mode *and* in `o` mode.
    # You may find  the re-installation in `o` mode  unexpected and unnecessary;
    # but I don't think it's an issue.
    # There should  be no side-effect;  except for one: according  to `maparg()`
    # and `:map`, *before* you had 1 mapping  in `no` mode, but *now* you have 2
    # mappings, one in `n` mode, and another in `o` mode.
    #
    #     noremap <C-Q> <Esc>
    #     vunmap <C-Q>
    #     map <C-Q>
    #     no <C-Q>       * <Esc>˜
    #
    #     var save: list<dict<any>> = MapSave('<C-Q>', 'n')
    #     MapRestore(save)
    #     map <C-Q>
    #     n  <C-Q>       * <Esc>˜
    #     o  <C-Q>       * <Esc>˜
    #
    # I don't consider that as an issue.
    # On the contrary, I prefer the second output, because `no` is not a real mode.
    #
    # ---
    #
    # I  think the  same pitfalls  could  apply to  `v` which  is a  pseudo-mode
    # matching the real modes `x` and `s`.
    #}}}
    var keys: list<string> = typename(arg_keys) =~ '^list' ? arg_keys : [arg_keys]

    var save: list<dict<any>>
    for key: string in keys
        # This `for` loop is only necessary if you intend `#save()` to support multiple modes:{{{
        #
        #     var save: list<dict<any>> = MapSave('<C-Q>', 'nxo')
        #                                                   ^^^
        #}}}
        for m: string in mode == '' ? [''] : mode
            var maparg: dict<any> = Maparg(key, m, wantlocal)
            save += [maparg]
        endfor
    endfor
    return save
enddef

# Usage:{{{
#
#     var my_global_mappings: list<dict<any>> = MapSave(['key1', 'key2', ...], 'n')
#     var my_local_mappings: list<dict<any>> = MapSave(['key1', 'key2', ...], 'n', true)
#}}}

export def MapRestore(save: list<dict<any>>) #{{{2
    # Why?{{{
    #
    # Sometimes, we may need to restore mappings stored in a variable which we
    # can't be sure will always exist.
    # In such  cases, it's  convenient to  use `get()` and  default to  an empty
    # list:
    #
    #     get(g:, 'unsure_variable', [])->MapRestore()
    #
    # To support this use case, we need to immediately return when we receive an
    # empty list, since there's nothing to restore.
    #}}}
    if empty(save)
        return
    endif

    for maparg: dict<any> in save
        # if the mapping was local to a buffer, check we're in the right one
        # If we are in the wrong buffer, why don't you temporarily load it?{{{
        #
        # Too many side-effects.
        #
        # You need  `:noautocmd` to suppress  autocmds, but it  doesn't suppress
        # `CursorMoved`, probably because the latter is fired too late.
        # From `:help :noautocmd`:
        #
        #    > Note that some autocommands are not triggered right away, but only later.
        #    > This specifically applies to |CursorMoved| and |TextChanged|.
        #
        # You also need to save and restore the alternate file.
        #
        # And you  need to save  and restore  some properties of  the buffer
        # where you re-install the mapping; like "was it unlisted?", "was it
        # unloaded?".
        #
        # And for  some reason,  some options  may be  reset in  the current
        # buffer (like `'conceallevel'`).
        #
        # ---
        #
        # Besides, it adds a lot of complexity, for a dubious gain:
        #
        #     var curbuf: number = bufnr('%')
        #     var origbuf: number = get(maparg, 'bufnr', 0)
        #     if get(maparg, 'buffer', false) && curbuf != origbuf
        #         if bufexists(origbuf)
        #             var altbuf: string = @#
        #             execute 'noautocmd buffer ' .. origbuf
        #         endif
        #     endif
        #     # ...
        #     # restore local mapping
        #     # ...
        #     if exists('altbuf')
        #         execute 'noautocmd buffer ' .. origbuf
        #         @# = altbuf
        #     endif
        #}}}
        if NotInRightBuffer(maparg)
            continue
        endif

        # if there was no mapping when `#save()` was invoked, there should be no
        # mapping after `#restore()` is invoked
        if maparg->has_key('unmapped')
            var cmd: string = GetMappingCmd(maparg)
            # `silent!` because there's  no guarantee that the  unmapped key has
            # been mapped  to sth after  being saved.  We move  `silent!` inside
            # the string,  otherwise it doesn't  work in Vim9  script (modifiers
            # are not all properly implemented yet).
            execute 'silent! ' .. cmd .. ' ' .. (maparg.buffer ? ' <buffer> ' : '') .. maparg.lhs
        else
            # Even if you refactor `#save()` so that it only supports 1 mode, `#restore()` can still receive several.{{{
            #
            #     noremap <C-Q> <Esc>
            #     nunmap <C-Q>
            #     echo maparg('<C-Q>', '', false, true).mode
            #     ov˜
            #     ^^
            #     2 modes
            #}}}
            for mode: string in maparg.mode
                # reinstall a saved mapping
                maparg->deepcopy()->extend({mode: mode})->Reinstall()
            endfor
        endif
    endfor
enddef

# Usage:{{{
#
#     MapRestore(save)
#
# `save` is a list obtained earlier by calling `MapSave()`.
# Its items are dictionaries describing saved mappings.
#}}}
#}}}1
# Core {{{1
def Maparg( #{{{2
    name: string,
    mode: string,
    wantlocal: bool
): dict<any>

    var maparg: dict<any> = maparg(name, mode, false, true)

    # There are 6 cases to consider.{{{
    #
    # Parameter 1: we want a local mapping or a global one; 2 possibilities.
    #
    # Parameter 2: `maparg()` returns:
    #
    #    - an empty dictionary
    #    - the info about a global mapping
    #    - the info about a local mapping
    #
    # 3 possibilities.
    #
    # 2 x 3 = 6.
    #
    # Note that the 2 parameters are orthogonal.
    # We can ask for  a local mapping and get info about a  global one, and vice
    # versa.  That's  because there  is no  way to  specify to  `maparg()` which
    # scope we're interested in.
    #
    # ---
    #
    # 3 of those cases can be handled with the same code.
    # They all  have in common  that `maparg()`  doesn't give any  relevant info
    # (because the key is not mapped).
    #
    # 2 other cases can – again – be handled with the same code.
    # They both have in common that `maparg()` gives us the desired info.
    #
    # In the 1 remaining case, `maparg()` doesn't give any relevant info, but we
    # don't know whether the key is mapped.
    #
    # This is why,  in the end, we  only have to write 3  `if`, `elseif` blocks,
    # and not 6.
    #}}}
    # there is no relevant mapping
    if empty(maparg) || wantlocal && !Islocal(maparg)
        # If there's no mapping, why do you still save this dictionary? {{{
        #
        # Suppose we have a key which is not mapped.
        # We save it with an empty dictionary.
        # Then, we map the key to something.
        # Finally,  we want  to restore  the key;  that means  deleting whatever
        # mapping may  now exist.  But to  be able to  unmap the key, we  need 3
        # information:
        #
        #    - is the mapping global or buffer-local (`<buffer>` argument)?
        #    - the lhs
        #    - the mode (normal, visual, ...)
        #
        # An empty dictionary doesn't contain any of this info.
        #}}}
        maparg = {
            unmapped: true,
            lhs: name,
            # we want to be consistent with `maparg()` which would return a space for `nvo`
            mode: mode == '' ? ' ' : mode,
            buffer: wantlocal,
        }

    # a local mapping is shadowing the global mapping we're interested in,
    # so we don't know whether there's a relevant mapping
    elseif !wantlocal && Islocal(maparg)
        # remove the shadowing local mapping
        execute mode .. 'unmap <buffer> ' .. name
        var local_maparg: dict<any> = deepcopy(maparg)->extend({bufnr: bufnr('%')})
        maparg = Maparg(name, mode, false)
        # restore the shadowing local mapping
        MapRestore([local_maparg])

    # there is a relevant mapping
    else
        extend(maparg, {
            # we don't want Vim to translate meta keys (e.g. `<M-b> → â`)
            lhs: name,
            # we want Vim to translate `<SID>`
            rhs: maparg(name, mode)->escape('|'),
        })
    endif

    if Islocal(maparg)
        # Save the buffer number, so that we can check we're in the right buffer
        # when we want to restore the buffer-local mapping.
        maparg.bufnr = bufnr('%')
    endif

    return maparg
enddef

def Reinstall(maparg: dict<any>) #{{{2
    execute GetMappingCmd(maparg)
        .. ' '
        .. (maparg.buffer  ? ' <buffer> ' : '')
        .. (maparg.expr    ? ' <expr>   ' : '')
        .. (maparg.nowait  ? ' <nowait> ' : '')
        .. (maparg.silent  ? ' <silent> ' : '')
        .. (maparg.script  ? ' <script> ' : '')
        .. maparg.lhs
        .. ' '
        .. maparg.rhs
enddef
#}}}1
# Util {{{1
def Islocal(maparg: dict<any>): bool #{{{2
    return get(maparg, 'buffer', false)
enddef

def NotInRightBuffer(maparg: dict<any>): bool #{{{2
    return Islocal(maparg) && bufnr('%') != get(maparg, 'bufnr', 0)
enddef

def GetMappingCmd(maparg: dict<any>): string #{{{2
    var cmd: string
    if maparg->has_key('unmapped')
        if maparg.mode == '!'
            cmd = 'unmap!'
        else
            cmd = maparg.mode .. 'unmap'
        endif
    else
        if maparg.mode == '!'
            cmd = maparg.noremap ? 'noremap!' : 'map!'
        else
            cmd = maparg.mode
            cmd ..= maparg.noremap ? 'noremap' : 'map'
        endif
    endif
    return cmd
enddef

