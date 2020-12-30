vim9script noclear

if exists('loaded') | finish | endif
var loaded = true

# Init {{{1

# TODO: Remove these lines once you find a fix for this issue:
# https://github.com/vim/vim/issues/5951
&t_TI = ''
&t_TE = ''

const IS_MODIFYOTHERKEYS_ENABLED = &t_TI =~# "\e\\[>4;[12]m"
# We need to run `:exe "set <f13>=\eb"` instead of `:exe "set <m-b>=\eb"` because:{{{
#
#    - we want to be able to insert some accented characters
#    - if we hit one of them by accident, we don't want to trigger some custom meta mapping
#}}}
# But not in a terminal where `modifyOtherKeys` is enabled, nor in the GUI.
# No need to, everything works fine there.
const USE_FUNCTION_KEYS = !has('gui_running') && !IS_MODIFYOTHERKEYS_ENABLED

var KEY2FUNC: dict<string>

if USE_FUNCTION_KEYS
    KEY2FUNC = {
        a: '<f12>',
        b: '<f13>',
        c: '<f14>',
        d: '<f15>',
        e: '<f16>',
        f: '<f17>',
        g: '<f18>',
        h: '<f19>',
        i: '<f20>',
        j: '<f21>',
        k: '<f22>',
        l: '<f23>',
        m: '<f24>',
        n: '<f25>',
        o: '<f26>',
        p: '<f27>',
        q: '<f28>',
        r: '<f29>',
        s: '<f30>',
        t: '<f31>',
        u: '<f32>',
        v: '<f33>',
        w: '<f34>',
        x: '<f35>',
        y: '<f36>',
        z: '<f37>',
        A: '<s-f12>',
        B: '<s-f13>',
        C: '<s-f14>',
        D: '<s-f15>',
        E: '<s-f16>',
        F: '<s-f17>',
        G: '<s-f18>',
        H: '<s-f19>',
        I: '<s-f20>',
        J: '<s-f21>',
        K: '<s-f22>',
        L: '<s-f23>',
        M: '<s-f24>',
        N: '<s-f25>',
        # Do *not* add 'O'.{{{
        #
        #     'O': '<s-f26>',
        #
        # It would cause a bug in xterm:
        #
        #     # start an xterm terminal
        #     $ vim -Nu NONE -S <(cat <<'EOF'
        #         set t_RV= t_TE= t_TI=
        #         exe "set <s-f26>=\eO"
        #         cno <s-f26> <nop>
        #         cno <f3> abc
        #     EOF
        #     )
        #
        #     " press:     : <F3>
        #     " expected:  'abc' is written on the command-line
        #     " actual:    'R' is written on the command-line
        #
        # ---
        #
        # At  least, don't  do  it  until you  can  stop  clearing `'t_TI'`  and
        # `'t_TE'` in xterm (for the moment, we have to because of another bug).
        #}}}
        P: '<s-f27>',
        Q: '<s-f28>',
        R: '<s-f29>',
        S: '<s-f30>',
        T: '<s-f31>',
        U: '<s-f32>',
        V: '<s-f33>',
        W: '<s-f34>',
        X: '<s-f35>',
        Y: '<s-f36>',
        Z: '<s-f37>',
    }

    def SetKeysyms()
        for [key, funckey] in items(KEY2FUNC)
            exe 'set ' .. funckey .. "=\e" .. key
        endfor
    enddef
    # We don't really need to delay until `VimEnter` for the moment.{{{
    #
    # But it could be necessary in the future if you want to run this code for gVim.
    # Indeed, in gVim,  if you set the keysyms during  the startup process, they
    # are somehow cleared at the end.
    #}}}
    au VimEnter * SetKeysyms()

    # Fix readline commands in a terminal buffer.{{{
    #
    # When you press `M-b`, the terminal writes `Esc` + `b` in the typeahead buffer.
    # And  since  we're going  to  run  `:set  <f13>=^[b`, Vim  translates  this
    # sequence into `<f13>` which – internally – is encoded as `<80>F3` (`:echo "\<f13>"`).
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
    # The issue affects gVim.
    # The issue affects Vim iff one of these statements is true:
    #
    #    - you run `:set <xxx>=^[b` (`xxx` being anything: `<M-b>`, `<f13>`, ...)
    #    - you use `:h modifyOtherKeys`
    #}}}
    def FixMetaReadline()
        for [key, funckey] in items(KEY2FUNC)
            exe 'tno ' .. funckey .. ' <esc>' .. key
        endfor
    enddef
    FixMetaReadline()

    def NopUnusedMetaChords()
        for funckey in values(KEY2FUNC)
            # we don't  want `<f37>` to  be inserted into  the buffer or  on the
            # command-line, if we press `<M-z>` and nothing is bound to it
            if maparg(funckey, 'i')->empty()
                exe 'ino ' .. funckey .. ' <nop>'
            endif
            if maparg(funckey, 'c')->empty()
                exe 'cno ' .. funckey .. ' <nop>'
            endif
        endfor
    enddef
    # delay until `VimEnter` so that we can  check which meta keys have not been
    # mapped to anything in the end
    au VimEnter * NopUnusedMetaChords()

elseif IS_MODIFYOTHERKEYS_ENABLED || has('gui_running')
    # Same issue as previously.{{{
    #
    # When  you press  `M-b`,  the terminal  sends some  special  sequence in  a
    # terminal where modifyOtherKeys is enabled, or `Esc` + `b` in gVim.
    #
    # In any case, Vim encodes the sequence  into `â`, which is then sent to the
    # shell.  Again, this  breaks all readline commands, and  again the solution
    # is to install a bunch of Terminal-Job  mode mappings so that Vim sends the
    # right sequences to the shell.
    #}}}
    def FixMetaReadline()
        for key in (range(char2nr('a'), char2nr('z'))
                + range(char2nr('A'), char2nr('Z')))
            ->map((_, v) => nr2char(v))
            exe 'tno <m-' .. key .. '> <esc>' .. key
        endfor
    enddef
    FixMetaReadline()

    def NopUnusedMetaChords()
        var lhs: string
        for key in (range(char2nr('a'), char2nr('z'))
                + range(char2nr('A'), char2nr('Z')))
            ->map((_, v) => nr2char(v))
            if toupper(key) == key
                lhs = '<M-S-' .. key .. '>'
            else
                lhs = '<M-' .. key .. '>'
            endif
            # we don't want  `ú` (!= `ù`) to  be inserted into the  buffer or on
            # the command-line, if we press `<M-z>` and nothing is bound to it
            if maparg(lhs, 'i')->empty()
                exe 'ino ' .. lhs .. ' <nop>'
            endif
            if maparg(lhs, 'c')->empty()
                exe 'cno ' .. lhs .. ' <nop>'
            endif
        endfor
    enddef
    au VimEnter * NopUnusedMetaChords()
endif

const FLAG2ARG = {
    S: '<script>',
    b: '<buffer>',
    e: '<expr>',
    n: '<nowait>',
    s: '<silent>',
    u: '<unique>',
    }

# Interface {{{1
export def MapMeta(key: string, rhs: string, mode: string, flags: string) #{{{2
    try
        exe (mode != '!' ? mode : '') .. (flags =~# 'r' ? 'map' : 'noremap') .. (mode == '!' ? '!' : '')
            .. ' ' .. MapArguments(flags)
            .. ' ' .. (USE_FUNCTION_KEYS ? KEY2FUNC[key] : '<m-' .. key .. '>')
            .. ' ' .. rhs
    catch /^Vim\%((\a\+)\)\=:E227:/
        echohl ErrorMsg
        unsilent echom v:exception
        echohl NONE
    endtry
enddef

export def MapMetaChord(key: string, symbolic = false): string #{{{2
    # give us a symbolic notation (e.g. `<m-a>`)
    if symbolic
        # terminal *not* supporting modifyOtherKeys
        if USE_FUNCTION_KEYS
            return KEY2FUNC[key]
        # GUI or terminal supporting modifyOtherKeys
        else
            if key == tolower(key)
                return '<m-' .. key .. '>'
            else
                return '<m-s-' .. key .. '>'
            endif
        endif

    # give us a byte sequence (e.g. `à` or `<80>F3`)
    else
        if USE_FUNCTION_KEYS
            return eval('"\' .. KEY2FUNC[key] .. '"')
        else
            if key == tolower(key)
                return eval('"\<m-' .. key .. '>"')
            else
                return eval('"\<m-s-' .. key .. '>"')
            endif
        endif
    endif
enddef

export def MapSave(keys: any, mode = '', wantlocal = false): list<dict<any>> #{{{2
# TODO(Vim9): `keys: any` → `keys: list<string>|string`
    if type(keys) != v:t_list && type(keys) != v:t_string | return [] | endif
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
    #     nno <c-q> <esc>
    #     var save = MapSave('<c-q>', '')
    #     noremap <c-q> <esc><esc>
    #     MapRestore(save)
    #     map <c-q>
    #     n  <C-Q>       * <Esc>~
    #     ov <C-Q>       * <Esc><Esc>~
    #     ^^
    #     the C-q mappings in these modes should have been removed
    #
    # We don't deal with  this pitfall here because it would  make the code more
    # complex, and it can be easily fixed in your code:
    #
    #     nnoremap <c-q> <esc><esc>
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
    #     noremap <c-q> <esc>
    #     vunmap <c-q>
    #     map <c-q>
    #     no <C-Q>       * <Esc>~
    #
    #     var save = MapSave('<c-q>', 'n')
    #     MapRestore(save)
    #     map <c-q>
    #     n  <C-Q>       * <Esc>~
    #     o  <C-Q>       * <Esc>~
    #
    # I don't consider that as an issue.
    # On the contrary, I prefer the second output, because `no` is not a real mode.
    #
    # ---
    #
    # I  think the  same pitfalls  could  apply to  `v` which  is a  pseudo-mode
    # matching the real modes `x` and `s`.
    #}}}
    var _keys = type(keys) == v:t_list ? keys : [keys]

    var save: list<dict<any>>
    for key in _keys
        # This `for` loop is only necessary if you intend `#save()` to support multiple modes:{{{
        #
        #     var save = MapSave('<c-q>', 'nxo')
        #                                  ^^^
        #}}}
        for m in mode == '' ? [''] : split(mode, '\zs')
            var maparg = Maparg(key, m, wantlocal)
            save += [maparg]
        endfor
    endfor
    return save
enddef

# Usage:{{{
#
#     var my_global_mappings = MapSave(['key1', 'key2', ...], 'n')
#     var my_local_mappings = MapSave(['key1', 'key2', ...], 'n', true)
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
    if empty(save) | return | endif

    for maparg in save
        # if the mapping was local to a buffer, check we're in the right one
        # If we are in the wrong buffer, why don't you temporarily load it?{{{
        #
        # Too many side-effects.
        #
        # You  need `:noa`  to suppress  autocmds, but  it doesn't  suppress
        # `CursorMoved`, probably because the latter is fired too late.
        # From `:h :noa`:
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
        # buffer (like `'cole'`).
        #
        # ---
        #
        # Besides, it adds a lot of complexity, for a dubious gain:
        #
        #     var [curbuf, origbuf] = [bufnr('%'), get(maparg, 'bufnr', 0)]
        #     if get(maparg, 'buffer', 0) && curbuf != origbuf
        #         if bufexists(origbuf)
        #             var altbuf = @#
        #             exe 'noa b ' .. origbuf
        #         endif
        #     endif
        #     # ...
        #     # restore local mapping
        #     # ...
        #     if exists('altbuf')
        #         noa exe 'b ' .. origbuf
        #         var @# = altbuf
        #     endif
        #}}}
        if NotInRightBuffer(maparg) | continue | endif

        # if there was no mapping when `#save()` was invoked, there should be no
        # mapping after `#restore()` is invoked
        if has_key(maparg, 'unmapped')
            var cmd = GetMappingCmd(maparg)
            # `sil!` because there's no guarantee that the unmapped key has been
            # mapped  to sth  after  being  saved.  We  move  `sil!` inside  the
            # string, otherwise  it doesn't work  in Vim9 script  (modifiers are
            # not all properly implemented yet).
            exe 'sil! ' .. cmd .. ' ' .. (maparg.buffer ? ' <buffer> ' : '') .. maparg.lhs
        else
            # Even if you refactor `#save()` so that it only supports 1 mode, `#restore()` can still receive several.{{{
            #
            #     noremap <c-q> <esc>
            #     nunmap <c-q>
            #     echo maparg('<c-q>', '', 0, 1).mode
            #     ov~
            #     ^^
            #     2 modes
            #}}}
            for mode in split(maparg.mode, '\zs')
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
def Maparg(name: string, mode: string, wantlocal: bool): dict<any> #{{{2
    var maparg = maparg(name, mode, 0, 1)

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
        exe mode .. 'unmap <buffer> ' .. name
        var local_maparg = deepcopy(maparg)->extend({bufnr: bufnr('%')})
        maparg = Maparg(name, mode, false)
        # restore the shadowing local mapping
        MapRestore([local_maparg])

    # there is a relevant mapping
    else
        extend(maparg, {
            # we don't want Vim to translate meta keys (e.g. `<M-b> → â`)
            lhs: name,
            # we want Vim to translate `<sid>`
            rhs: maparg(name, mode)->escape('|'),
            })
    endif

    if Islocal(maparg)
        # Save the buffer number, so that we can check we're in the right buffer
        # when we want to restore the buffer-local mapping.
        extend(maparg, {bufnr: bufnr('%')})
    endif

    return maparg
enddef

def Reinstall(maparg: dict<any>) #{{{2
    var cmd = GetMappingCmd(maparg)
    exe cmd
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
def MapArguments(flags: string): string #{{{2
    return split(flags, '\zs')->map((_, v) => get(FLAG2ARG, v, ''))->join()
enddef

def Islocal(maparg: dict<any>): bool #{{{2
    return get(maparg, 'buffer', 0)
enddef

def NotInRightBuffer(maparg: dict<any>): bool #{{{2
    return Islocal(maparg) && bufnr('%') != get(maparg, 'bufnr', 0)
enddef

def GetMappingCmd(maparg: dict<any>): string #{{{2
    var cmd: string
    if has_key(maparg, 'unmapped')
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

