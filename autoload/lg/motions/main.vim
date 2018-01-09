" TODO:
" We invoke `maparg()` too many times.
" To optimize.
"
" It's called in:
"
"     lg#motions#main#make_repeatable() (unavoidable, because initial)
"     s:populate()                      (unavoidable, because we need maparg but for another direction)
"     s:get_motion_info()               (avoidable?)
"
" `s:get_motion_info()` is called in:
"
"         s:move_again()
"         s:move()
"         s:get_direction()
"         s:update_last_motion()

" FIXME:
"     In vimrc go to a function containing a `:return` statement.
"     Enter visual mode.
"     Press `%` on `fu!`
"     Press `;`.
"     Press Escape
"     Press `;`.
"
" Now `;` makes us enter visual mode. It shouldn't. We want a motion in normal
" mode.
"
" Also, prior to that, `%` in normal mode is not silent. I can see the `matchit`
" function being called. The original mapping was silent. The wrapper should
" be too.

" FIXME:
" `;` doesn't always repeat the motion.
" Press `V down ;`.

" TODO:
" Split the code in several files if needed.
" Also, make the signature of the main function similar to `submode#map()`;
" which means we shouldn't use a dictionary of arguments, just plain arguments.
" This would allow us to eliminate `lg#motions#main#make_repeatable()`.
"
" Also, I'm not satisfied with the current architecture of files for this plugin.
" Also, maybe we should move it back to its own plugin.

" TODO:
" more granular listing
" :ListRepeatableMotions -this_axis -this_scope -this_mode

" TODO:
" In the listing, the mode should be printed.

" TODO:
" Document the fact that  when the plugin installs a wrapper for  a key, it uses
" :noremap.
"
" 2 consequences:
"
" If the original mapping needs recursiveness, you'll need to tweak its definition
" and use `feedkeys()`.
"
" If you need different definitions depending on the mode (n or v or o), you'll need
" to tweak its definition and use `<expr>` + `mode(1)` to distinguish the current mode
" inside a function.

" Terminology:{{{
"
"     axis
"
"             type of space in which we are moving:
"
"                     • buffer text
"                     • filesystem
"                     • versions of buffer
"
"                           in this particular case, the “motion” is in fact an edition
"                           the edition makes us move from a version of the buffer to another
"
"                     • option values
"
"     motion
"
"             dictionary containing 3 keys:
"
"                 • bwd:     output of `maparg('<left>')` where '<left>' is
"                            backward motion
"
"                 • fwd:     same thing for `<right>` as the forward motion
"
"                 • axis:    number which determines how the motion should be
"                            repeated:
"
"                                1:  with a bare , ;
"                                2:                         z
"                                3:  same but prefixed with +
"                                4:                         co
"                                …
"
"                            the 2nd axis could be  reserved to motions moving the
"                            focus across different files, or resizing a window
"
"                            the 3rd axis for editions which can be performed in 2 directions
"
"                            the 4th axis for cycling through options values
"}}}
fu! s:init() abort "{{{1
    let s:default_maparg     = { 'noremap': 1, 'expr': 0, 'nowait': 0, 'silent': 0, 'buffer': 0}
    let s:repeatable_motions = []

    let s:axes = {
    \              '1': 1,
    \              '2': 2,
    \              '3': 3,
    \              '4': 4,
    \            }

    let s:n_axes = len(s:axes)

    let s:recursive_mapcmd = {
    \                          'n':  'nmap',
    \                          'x':  'xmap',
    \                          'no': 'omap',
    \                          '':   'map',
    \                        }

    let s:non_recursive_mapcmd = {
    \                              'n':  'nnoremap',
    \                              'x':  'xnoremap',
    \                              'no': 'onoremap',
    \                              '':   'noremap',
    \                            }

    for i in range(1, s:n_axes)
        let s:last_motion_on_axis_{i} = ''
        " Currently not used for i=2. But could be useful for a custom mapping.
        " See :h repeatable-motions-relative-direction.
        let s:repeating_motion_on_axis_{i} = 0
    endfor
endfu
call s:init()

" Command {{{1

com!  ListRepeatableMotions  call s:list_all_motions()

fu! s:get_direction(lhs) abort "{{{1
    let motion = s:get_motion_info(a:lhs)
    let is_fwd = s:translate_lhs(a:lhs) ==# s:translate_lhs(motion.fwd.lhs)
    return is_fwd ? 'fwd' : 'bwd'
endfu

fu! s:get_mapcmd(mode, lhs, maparg) abort "{{{1
    let is_recursive = !get(a:maparg, 'noremap', 1)
    "                                            │
    "                                            └ by default, we don't want
    "                                              a recursive wrapper mapping

    let mapcmd = s:{is_recursive ? '' : 'non_'}recursive_mapcmd[a:mode]

    let mapcmd .= '  <expr>'
    if get(a:maparg, 'buffer', 0)
        let mapcmd .= '<buffer>'
    endif
    if get(a:maparg, 'nowait', 0)
        let mapcmd .= '<nowait>'
    endif
    if get(a:maparg, 'silent', 0)
        let mapcmd .= '<silent>'
    endif

    return mapcmd
endfu

fu! s:get_motion_info(lhs) abort "{{{1
    " return any motion which:
    "
    "     • is registered as repeatable  (i.e. is present inside [s:|b:]repeatable_motions)
    "     • contains a lhs (forward or backward) equal to the one received by the function


    " TODO:
    " in `maparg()`, replace '' with the actual mode
    let motions = get(maparg(a:lhs, '', 0, 1), 'buffer', 0)
    \?                get(b:, 'repeatable_motions', [])
    \:                s:repeatable_motions

    for m in motions
        if index([s:translate_lhs(m.bwd.lhs), s:translate_lhs(m.fwd.lhs)],
        \        s:translate_lhs(a:lhs)) >= 0
            return m
        endif
    endfor
endfu

fu! s:install_wrapper(mapcmd, buffer, bwd, fwd) abort "{{{1
    exe a:mapcmd.'  '.a:bwd.'  <sid>move('.string(a:bwd).', '.a:buffer.', 1)'
    exe a:mapcmd.'  '.a:fwd.'  <sid>move('.string(a:fwd).', '.a:buffer.', 1)'
endfu

fu! s:invalid_axis_or_direction(axis, direction) abort "{{{1
    let is_valid_axis = index(values(s:axes), a:axis) >= 0
    let is_valid_direction = index(['bwd', 'fwd'], a:direction) >= 0
    return !is_valid_axis || !is_valid_direction
endfu

fu! s:is_inconsistent(motion) abort "{{{1
    if   a:motion.bwd.buffer && !a:motion.fwd.buffer
    \|| !a:motion.bwd.buffer &&  a:motion.fwd.buffer
        try
            throw printf('%s and %s must be buffer or global mappings',
            \             motion.bwd.lhs,
            \             motion.fwd.lhs)
        catch
            return lg#catch_error()
        finally
            return 1
        endtry
    endif
    return 0
endfu

fu! s:list_all_motions() abort "{{{1
    for i in range(1, s:n_axes)
        let motions_on_axis_{i} = {'global': [], 'buffer_local': []}
    endfor

    for l in [s:repeatable_motions, get(b:, 'repeatable_motions', [])]
        for m in l
            let text = ''
            let text .= m.bwd.lhs
            let text .= ' : '.m.fwd.lhs

            " make last motion  used on this axis visible, by  prefixing it with
            " an asterisk
            let n = m.axis
            if index([m.bwd.lhs, m.fwd.lhs], s:last_motion_on_axis_{n}) >= 0
                let text = '* '.text
            endif
            call add(l == get(b:, 'repeatable_motions', [])
            \?           motions_on_axis_{n}.buffer_local
            \:           motions_on_axis_{n}.global,
            \        '  '.text)
        endfor
    endfor

    " TODO:
    " Instead of simply echo'ing the list, try to display it in the preview window.
    "
    "     gives us persistence
    "     make it easier to copy some information
    "     make it easier to create some custom syntax highlighting
    for n in range(1, s:n_axes)
        call s:list_motions_on_this_axis(n, motions_on_axis_{n})
    endfor
endfu

fu! s:list_motions_on_this_axis(n, motions_on_this_axis) abort "{{{1
    if a:n > 1
        echo "\n"
    endif
    echohl Title
    echo 'Motions on axis:  '.a:n
    echohl NONE
    if empty(a:motions_on_this_axis.global) && empty(a:motions_on_this_axis.buffer_local)
        echo '  no repeatable motions on axis '.a:n
    else
        for scope in ['global', 'buffer_local']
            if !empty(a:motions_on_this_axis[scope])
                echohl Visual
                echo "\n".substitute(scope, '_', '-', '')
                echohl NONE
                for m in a:motions_on_this_axis[scope]
                    echo m
                endfor
            endif
        endfor
    endif
endfu

fu! s:make_keys_feedable(seq) abort "{{{1
    let m = escape(a:seq, '\')
    let m = escape(m, '"')
    let special_chars = [
    \                     '<BS>',      '<Tab>',     '<FF>',         '<t_',
    \                     '<cr>',      '<Return>',  '<Enter>',      '<Esc>',
    \                     '<Space>',   '<lt>',      '<Bslash>',     '<Bar>',
    \                     '<Del>',     '<CSI>',     '<xCSI>',       '<EOL>',
    \                     '<Up>',      '<Down>',    '<Left>',       '<Right>',
    \                     '<F',        '<Help>',    '<Undo>',       '<Insert>',
    \                     '<Home>',    '<End>',     '<PageUp>',     '<PageDown>',
    \                     '<kHome>',   '<kEnd>',    '<kPageUp>',    '<kPageDown>',
    \                     '<kPlus>',   '<kMinus>',  '<kMultiply>',  '<kDivide>',
    \                     '<kEnter>',  '<kPoint>',  '<k0>',         '<S-',
    \                     '<C-',       '<M-',       '<A-',          '<D-',
    \                     '<Plug',
    \                   ]
    for s in special_chars
        let m = substitute(m, '\c\('.s.'\)', '\\\1', 'g')
    endfor

    " Don't use `string()`.
    " We need double quotes to translate special characters.
    sil exe 'return "'.m.'"'
endfu

fu! s:make_it_repeatable(what, maparg) abort "{{{1
    let mode = a:what.mode
    let buffer = a:what.buffer
    let bwd = a:what.motions.bwd
    let fwd = a:what.motions.fwd
    let axis = a:what.motions.axis
    let is_recursive = !get(a:maparg, 'noremap', 1)

    " Purpose:{{{
    "
    "     1. Install wrapper mappings around a pair of motion mappings, to
    "        save the last motion.
    "
    "     2. Add to the list `[s:|b:]repeatable_motions` a dictionary
    "        containing all the information relative to this original pair of
    "        motion mappings. This list is used by `s:bufreadpost()` to know
    "        which …
    "        TODO: finish this paragraph
    "}}}
    " Could we install the wrapper mappings BEFORE populating `s:repeatable_motions`?{{{
    "
    " No. It would cause `s:populate()` to capture the definition of the wrapper
    " mapping instead of  the original one. So, when we would  type a motion, we
    " would enter  an infinite  loop: the  wrapper would  call itself  again and
    " again until E132.
    "
    " The fact  that the wrapper  mapping is, by default,  non-recursive doesn't
    " change  anything. When  we  would  press   the  lhs,  Vim  would  evaluate
    " `s:move('lhs', 0, 1)`.   At the end, Vim would compute  the keys to press:
    " the latter would be the output  of `s:move('lhs', 0, 1)`. That's where the
    " recursion comes from. It's like pressing  `cd`, where `cd` is defined like
    " so:
    "
    "     nno  <expr>  cd  Func()
    "     fu! Func()
    "         return Func()
    "     endfu
    "}}}

    let motion = { 'axis': axis }
    " Why don't we write an assignment to populate `motion`?{{{
    "
    " `motion` is an array (!= scalar), so Vim passes it to `s:populate()`
    " as a REFERENCE (not as a VALUE), and the function operates in-place.
    " IOW: no need to write:
    "
    "         let motion = s:populate(motion, …)
    "}}}
    call s:populate(motion, mode, bwd, 0, a:maparg)
    " `motion` value is now sth like:{{{
    "
    " { 'axis' : 1,
    "   'bwd'    : {'expr': 0, 'noremap': 1, 'lhs': '…', 'mode': ' ', … }}
    "                                                             │
    "                                                             └ nvo
    "}}}
    call s:populate(motion, mode, fwd, 1)
    " `motion` value is now sth like:{{{
    "
    " { 'axis' : 1,
    "   'bwd'    : {'expr': 0, 'noremap': 1, 'lhs': '…', 'mode': ' ', … },
    "   'fwd'    : {'expr': 0, 'noremap': 1, 'lhs': '…', 'mode': ' ', … }}
    "}}}

    " How could we get an inconsistent motion?{{{
    "
    " Install a global mapping in one direction:      <left>
    " Install a buffer-local mapping in the other:    <right>
    " Then:
    "
    "         call s:make_it_repeatable({'mode': '',
    "         \                          'buffer': 0,
    "         \                          'motions': {'bwd': '<left>', 'fwd': '<right>', 'axis': 1})
    "
    " TODO:
    " Are you sure this explanation is still valid?
    "}}}
    if s:is_inconsistent(motion)
        return
    endif

    " TODO:
    " Explain why this is necessary.
    " `b:repeatable_motions` may not exist. So we must make sure it exists.
    " I don't want to automatically create it in an autocmd. I only want it
    " if necessary. And we can't use `get(b:, 'repeatable_motions', [])` here
    " to avoid an error  in case it doesn't exist, because it  would give us an
    " empty list which would NOT be the reference to `b:repeatable_motions`.
    " It would just be an empty list. So, `:ListRepeatableMotions` would not show
    " us buffer-local mappings, because we would never populate `b:repeatable_motions`.
    " We would just populate a random list.
    if motion.bwd.buffer && !exists('b:repeatable_motions')
        let b:repeatable_motions = []
    endif

    " What does `repeatable_motions` contain?{{{
    "
    " A reference to a list of motions:  [s:|b:]repeatable_motions
    "}}}
    " Why a reference, and not a value?{{{
    "
    " Vim always assigns a REFERENCE of an array to a variable, not its VALUE.
    " So, `repeatable_motions`  contains a reference to  its script/buffer-local
    " counterpart.
    "}}}
    let repeatable_motions = {motion.bwd.buffer ? 'b:' : 's:'}repeatable_motions

    " TODO:
    " This prevents `b:repeatable_motions` from growing when we reload a buffer.
    " But it feels wrong to wait so late.
    " I would prefer to reset the variable early.
    " Besides, it may write something in the log messages (type coD, then :e).
    if s:motion_already_repeatable(motion, repeatable_motions)
        return
    endif

    let mapcmd = s:get_mapcmd(mode, bwd, a:maparg)
    call s:install_wrapper(mapcmd, buffer, bwd, fwd)

    call add(repeatable_motions, motion)

    if motion.bwd.buffer
        " Why?{{{
        "
        " Watch:
        "
        "     coD
        "     :e foo.vim
        "     :Rename bar.vim
        "     :Rename baz.vim
        "
        " Why these errors?
        "
        " This is because `:Rename` execute  `:filetype detect`, which loads Vim
        " filetype plugins. In the  latter, we call a function  from this plugin
        " to  make  some  motions  repeatable. When  the  filetype  plugins  are
        " re-sourced,  Vim  removes  the  mappings  (b:undo_ftplugin). But,  our
        " current plugin hasn't erased the repeatable wrappers from its database
        " (b:repeatable_motions).
        "
        " We  must eliminate  the  database whenever  the  filetype plugins  are
        " resourced.  We could do it directly from the Vim filetype plugins, but
        " it  seems unreliable.   We'll undoubtedly  forget to  do it  sometimes
        " for  other  filetypes.   Instead,  the current  plugin  should  update
        " `b:undo_ftplugin`.
        "}}}
        call s:update_undo_ftplugin()
    endif
endfu

fu! lg#motions#main#make_repeatable(what) abort "{{{1
    let mode = a:what.mode
    let buffer = a:what.buffer
    let motions = a:what.motions

    " try to make all the motions received repeatable
    for m in motions
        let maparg = maparg(m.bwd, mode, 0, 1)
        "             ┌ the motion is local to a buffer,
        "             │ and a mapping whose {lhs} is `m.bwd` exists
        "             │
        if !buffer || get(maparg, 'buffer', 0)
            " TODO:
            " It's the only location where we call `s:make_it_repeatable()`
            " with `m.bwd`. Everywhere else, we pass `m.bwd.lhs`.
            " Why the difference?
            let what = extend(deepcopy(a:what), {'motions': m})
            call s:make_it_repeatable(what, maparg)
        endif
    endfor
endfu

fu! s:motion_already_repeatable(motion, repeatable_motions) abort "{{{1
    let bwd = a:motion.bwd.lhs
    let fwd = a:motion.fwd.lhs
    let mode_bwd = a:motion.bwd.mode
    let mode_fwd = a:motion.fwd.mode

    "   ┌ Motion
    "   │
    for m in a:repeatable_motions
        " TODO:
        " Are both conditions necessary?
        " A single one wouldn't be enough?
        if  (bwd ==# m.bwd.lhs && mode_bwd ==# m.bwd.mode)
        \|| (fwd ==# m.fwd.lhs && mode_fwd ==# m.fwd.mode)
            try
                throw printf("[repeatable motion] '%s : %s' already defined",
                \            m.bwd.lhs, m.fwd.lhs)
            catch
                call lg#catch_error()
            finally
                return 1
            endtry
        endif
    endfor
    return 0
endfu

fu! s:move(lhs, buffer, update_last_motion) abort "{{{1
    " TODO:
    " The  only  location   where  `s:move()`  is  passed  a   second  non  zero
    " argument,  is  in  `s:move_again()`. This  check makes  sure  we  don't
    " update the last motion stored in `s:last_motion_on_axis_{number}` when
    " `s:move_again()` calls `s:move()`. Is it really necessary? Why?
    if a:update_last_motion
        call s:update_last_motion(a:lhs)
    endif

    let dir_key = s:get_direction(a:lhs)
    let motion = s:get_motion_info(a:lhs)

    let is_expr_mapping = motion[dir_key].expr
    if motion[dir_key].rhs =~# '\c<sid>'
        let motion[dir_key].rhs =
        \    substitute(motion[dir_key].rhs, '\c<sid>', '<snr>'.motion[dir_key].sid.'_', 'g')
    endif

    " TODO:
    " Shouldn't we invoke `s:make_keys_feedable()` in BOTH cases?
    " What if there are special keys in the rhs of an expr mapping?
    return is_expr_mapping
    \?         eval(motion[dir_key].rhs)
    \:         s:make_keys_feedable(motion[dir_key].rhs)
endfu

fu! s:move_again(axis, dir) abort "{{{1
    " This function is called by various mappings whose suffix is `,` or `;`.

    " make sure the mapping is correctly defined
    " and we've used at least one motion on this axis
    if  s:invalid_axis_or_direction(a:axis, a:dir)
    \|| empty(s:last_motion_on_axis_{a:axis})
        return ''
    endif

    " get last motion on the axis provided
    let motion = s:get_motion_info(s:last_motion_on_axis_{a:axis})

    " TODO:
    " How could we get an unrecognized motion?
    " You would need:
    "
    "     no motion inside `[b:|s:]repeatable_motions`  has a `lhs` (m.bwd.lhs /
    "     m.fwd.lhs) equal to s:last_motion_on_axis_{a:axis}
    "
    " The latter is defined in `update_last_motion()`.
    " Update:
    " Maybe if  the last motion  is buffer local, we  change the buffer,  and in
    " this one the motion doesn't exist…
    if type(motion) != type({})
        return ''
    endif

    " What does this variable mean?{{{
    "
    " It's a numeric flag, whose value can be:
    "
    "       ┌────┬────────────────────────────────────────────────────────┐
    "       │ 0  │ we are NOT going to repeat a motion on this axis       │
    "       ├────┼────────────────────────────────────────────────────────┤
    "       │ -1 │ we are about to repeat a motion BACKWARDS on this axis │
    "       ├────┼────────────────────────────────────────────────────────┤
    "       │ 1  │ we are about to repeat a motion FORWARDS on this axis  │
    "       └────┴────────────────────────────────────────────────────────┘
    "}}}
    " Why do we set it now?{{{
    "
    " At the end of `s:move()` we return the keys to press.
    " To get them, we fetch the rhs associated with the lhs which was passed to
    " the function. But if the mapping uses the `<expr>` argument, we EVALUATE
    " the rhs. Besides, if we have previously pressed `fx`, the rhs is:
    "
    "     <sid>tf_workaround('f')
    "
    " And the code in `s:tf_workaround()` IS influenced by
    " `s:repeating_motion_on_axis_1`.
    "}}}
    let s:repeating_motion_on_axis_{a:axis} = a:dir ==# 'fwd' ? 1 : -1

    let seq = s:move(motion[a:dir].lhs, motion[a:dir].buffer, 0)

    " TODO: Why do we reset all these variables?
    " Update:
    " I think it's for a custom function which we could define to implement
    " a special motion like `fFtT`. Similar to `s:tf_workaround()`.
    " `fFtT` are special because the lhs, which is saved for repetition, doesn't
    " contain the necessary character which must be passed to the command.
    "
    " Note that `fFtT` are specific to the axis 1, but we could want to define
    " special motions on other axes. That's why, I think, we need to reset
    " ALL variables.
    for i in range(1, s:n_axes)
        let s:repeating_motion_on_axis_{i} = 0
    endfor

    " if we're using `]q` &friends (to move into a list of files), we need to
    " redraw all statuslines, so that the position in the list is updated
    " immediately
    if a:axis == 2
        call timer_start(0, {-> execute('redraws!')})
    endif

    " Why not returning the sequence of keys directly?{{{
    "
    " The   ; , z; z,   mappings are non-recursive (`:noremap`),
    " because that's what we want by default.
    " However, for some motions, we may need recursiveness.
    " Example: `]e` to move the line down.
    "
    " Therefore, if we returned the sequence directly, it wouldn't be expanded
    " even when it needs to be. So, we use `feedkeys()` to write it in the
    " typeahead buffer recursively or non-recursively depending on how the
    " original motion was defined.
    "}}}
    let is_recursive = !motion[a:dir].noremap
    call feedkeys(seq, 'i'.(is_recursive ? '' : 'n').'t')

    " if the sequence is an Ex command, it may appear on the command-line
    " make sure to erase it if the orginal motion was silent
    let is_silent = motion[a:dir].silent
    if is_silent
        " FIXME:
        " `:redraw!` is overkill. Besides, if the motion wants to echo a message,
        " it will probably be erased. That's not what <silent> does.
        " <silent> only prevents the rhs from being echo'ed. But the rhs can still
        " display a message if it wants to.
        "
        " Besides, try that:
        "
        "     ]oL
        "     co;
        "     ;
        "
        " The command-line seems to flash.
        "
        " Update:
        " Maybe we could install a temporary `<plug>` mapping which would mimic
        " the original (using `<silent>` if necessary)?
        call timer_start(0, {-> execute('redraw!')})
    endif
    return ''
endfu

fu! s:populate(motion, mode, lhs, is_fwd, ...) abort "{{{1
    let maparg = a:0 ? a:1 : maparg(a:lhs, a:mode, 0, 1)
    let dir = a:is_fwd ? 'fwd' : 'bwd'

    " make a custom mapping repeatable
    if !empty(maparg)
        let a:motion[dir] = maparg
    " make a default motion repeatable
    else
        let a:motion[dir] = extend(deepcopy(s:default_maparg), {'mode': a:mode })
        let a:motion[dir].lhs = a:lhs
        let a:motion[dir].rhs = a:lhs
    endif
endfu

fu! s:tf_workaround(cmd) abort "{{{1
    " FIXME:
    " How to make the code integrate our custom logic to use vim-sneak?
    " For the moment, we've removed this from `s:default_motions`:
    "
    "         {'bwd': 'F' ,  'fwd': 'f' ,  'axis': 1}
    "         {'bwd': 'T' ,  'fwd': 't' ,  'axis': 1}
    "
    " Make `fFtT` repeatable.

    " TODO:
    " We don't need to call this function to make `)` repeatable,
    " so why do we need to call it to make `fx` repeatable?
    "
    " What is special about making `fx` repeatable, compared to `)`?
    "
    " Update:
    " `s:move_again()` → `s:move()` → `s:tf_workaround()`
    "                     │
    "                     └ something different happens here depending on whether
    "                       the last motion is a simple `)` or a special `fx`
    "
    "                       `s:move()` saves the last motion as being:
    "
    "                               `)` when we press `)`
    "                               `f` when we press `fx`
    "
    "                       It fails to save the argument passed to the `f` command.
    "
    "                       Why?
    "                       Because `s:move()` saves the lhs of the mapping used.
    "                       `f` is the lhs of our mapping. Not `fx`.
    "                       `x` is merely asked via `getchar()`.
    "                       It doesn't explicitly belong to the lhs.
    "
    "                       So, there's an issue here.
    "                       `f` is not a sufficient information to successfully repeat `fx`.
    "                       2 solutions:
    "
    "                               1. save `x` to later repeat `fx`
    "                               2. repeat `fx` by pressing `;`
    "
    "                       The 1st solution will work with `tx` and `Tx`, but only the 1st time.
    "                       After that, the cursor won't move, because it will always be stopped
    "                       by the same `x`.
    "                       So we must use the 2nd solution, and press `;`.
    "
    "                       to finish

    " What's the purpose of this `if` conditional?{{{
    "
    " This function can be called:
    "
    "     •   directly from a  [ftFT]  mapping
    "     • indirectly from a  [;,]    mapping
    "       │
    "       └ s:move_again()  →  s:move()  →  s:tf_workaround()
    "
    " It needs to distinguish from where it was called.
    " Because in  the first  case, it  needs to  ask the  user for  a character,
    " before returning the  keys to press. In the other, it  doesn't need to ask
    " for anything.
    "}}}
    if s:repeating_motion_on_axis_1
    "                             │
    "                             └ `[tfTF]x` motions are specific to the axis 1,
    "                                so there's no need to check `s:repeating_motion_on_axis_2,3,…`

        return (s:tf_cmd ==# a:cmd) ? ';' : ','
        "       │            │
        "       │            └ TODO: What is this? When we press `;` after `fx`, how is `a:cmd` obtained?
        "       │
        "       │                     Update: It's `f`.
        "       │                     Here's what happens approximately:
        "       │
        "       │                     ;  →  s:move_again(1,'fwd'))
        "       │
        "       │                                   s:get_motion_info(s:last_motion_on_axis_1)  saved in `motion`
        "       │                                                     │
        "       │                                                     └ 'f'
        "       │
        "       │                           s:move(motion.fwd.lhs, 0, 0)
        "       │                                  │
        "       │                                  └ 'f'
        "       │
        "       │                                   s:get_motion_info(a:lhs)  saved in `motion`
        "       │                                                     │
        "       │                                                     └ 'f'
        "       │
        "       │                                   s:get_direction(a:lhs)  saved in `dir_key`
        "       │                                   │
        "       │                                   └ 'fwd'
        "       │
        "       │                           eval(motion[dir_key].rhs)
        "       │                                └─────────────────┤
        "       │                                                  └ s:tf_workaround('f')
        "       │                                                                     │
        "       │                                                                     └ !!! a:cmd !!!
        "       │
        "       │                            Consequence of all of this:
        "       │                            our plugin normalizes the direction of the motions `,` and `;`
        "       │                            i.e. `;` always moves the cursor forward no matter whether
        "       │                            we previously used f or F or t or T
        "       │                            In fact, it seems the normalization applies also to non-f motions!
        "       │                            Document this automatic normalization somewhere.
        "       │
        "       └ last command among the set [tfTF]
    else
        let s:tf_cmd = a:cmd
        return a:cmd . nr2char(getchar())
    endif
endfu

fu! s:translate_lhs(lhs) abort "{{{1
    return eval('"'.substitute(a:lhs, '<\ze[^>]\+>', '\\<', 'g').'"')
endfu

fu! s:update_last_motion(lhs) abort "{{{1
    let motion = s:get_motion_info(a:lhs)
    let n = motion.axis
    let s:last_motion_on_axis_{n} = s:translate_lhs(a:lhs)
endfu

fu! s:update_undo_ftplugin() abort "{{{1
    if stridx(get(b:, 'undo_ftplugin', ''), 'unlet! b:repeatable_motions') == -1
        let b:undo_ftplugin =          get(b:, 'undo_ftplugin', '')
        \                     . (empty(get(b:, 'undo_ftplugin', '')) ? '' : '|')
        \                     . 'unlet! b:repeatable_motions'
    endif
endfu

" Mappings {{{1

" TODO:
" For the moment, we've removed `<unique>` for    , ; t T f F
" Restore later (once it doesn't raise any error).

" To support visual mode + operator pending mode, we need `:noremap` instead of `:nno`.
"
" TODO:
" Old comment, it should be eliminated. I keep it because it's not clear I can.
" Make some tests with Up Down motions, and press `;` in all modes.
"
" If you need recursiveness (for example for a `<plug>`), use `feedkeys()`.
" Example:{{{
"
"                                        ┌ necessary to get the full name of the mode
"                                        │ otherwise, in operator-pending mode, we would get 'n',
"                                        │ instead of 'no'
"                                        │
"     noremap  <expr>  <down>  Func(mode(1),1)
"     noremap  <expr>  <up>    Func(mode(1),0)
"
"     fu! Func(mode, is_fwd) abort
"         let plug_dir = a:is_fwd ? 'fwd' : 'bwd'
"         let seq = index(['v', 'V', "\<c-v>"], a:mode) >= 0
"         \?            "\<plug>(return-visual-".plug_dir.')'
"         \:        a:mode ==# 'no'
"         \?            "\<plug>(return-op-".plug_dir.')'
"         \:            "\<plug>(return-normal-".plug_dir.')'
"         call feedkeys(seq, 'i')
"         return ''
"     endfu
"
"     nno  <silent>  <plug>(return-normal-bwd)  :<c-u>call search('^\s*return\>', 'bW')<cr>
"     xno  <silent>  <plug>(return-visual-bwd)  :<c-u>exe 'norm! gv' <bar> call search('^\s*return\>', 'bW')<cr>
"                                                     └────────────┤
"                                                                  └ necessary for the search to be done
"                                                                    in visual mode
"
"     ono  <silent>  <plug>(return-op-bwd)      :<c-u>call search('^\s*return\>', 'bW')<cr>
"
"     nno  <silent>  <plug>(return-normal-fwd)  :<c-u>call search('^\s*return\>', 'W')<cr>
"     xno  <silent>  <plug>(return-visual-fwd)  :<c-u>exe 'norm! gv' <bar> call search('^\s*return\>', 'W')<cr>
"     ono  <silent>  <plug>(return-op-fwd)      :<c-u>call search('^\s*return\>', 'W')<cr>
"}}}
noremap  <expr>            ,  <sid>move_again(1,'bwd')
noremap  <expr>            ;  <sid>move_again(1,'fwd')

noremap  <expr><unique>   z,  <sid>move_again(2,'bwd')
noremap  <expr><unique>   z;  <sid>move_again(2,'fwd')
noremap  <expr><unique>   +,  <sid>move_again(3,'bwd')
noremap  <expr><unique>   +;  <sid>move_again(3,'fwd')
nno      <expr><unique>  co,  <sid>move_again(4,'bwd')
nno      <expr><unique>  co;  <sid>move_again(4,'fwd')

noremap  <expr>  <plug>(z_semicolon)     <sid>move_again(2,'fwd')
noremap  <expr>  <plug>(z_comma)         <sid>move_again(2,'bwd')
noremap  <expr>  <plug>(plus_semicolon)  <sid>move_again(3,'fwd')
noremap  <expr>  <plug>(plus_comma)      <sid>move_again(3,'bwd')
nno      <expr>  <plug>(co_semicolon)    <sid>move_again(4,'fwd')
nno      <expr>  <plug>(co_comma)        <sid>move_again(4,'bwd')

noremap  <expr>  t  <sid>tf_workaround('t')
noremap  <expr>  T  <sid>tf_workaround('T')
noremap  <expr>  f  <sid>tf_workaround('f')
noremap  <expr>  F  <sid>tf_workaround('F')


" Why here, and not in `vimrc`?{{{
"
" Because every time we would resource it, it would overwrite the wrapper,
" and we would lose the ability to repeat.
" Alternatively, we could use a guard `if has('vim_starting')`.
"}}}
nno  <unique>  g;  g,zv
nno  <unique>  g,  g;zv

" Why?{{{
"
" When I press `]s` to move the cursor to the next wrongly spelled
" word, I want to ignore rare words / words for another region, which
" is what `]S` does.
"}}}
nno  <unique>  [s  [S
nno  <unique>  ]s  ]S

" Why? {{{
"
" By default, `zh` and `zl` move the cursor on a long non-wrapped line.
" But at the same time, we use `zj` and `zk` to split the window.
" I don't like  the `hjkl` being used  with a same prefix (`z`)  for 2 different
" purposes. So, instead we'll use `[S` and `]S`.
" Warning:
" This  shadows the  default `]S`  which moves  the cursor  to the  next wrongly
" spelled word (ignoring rare words and words for other regions).
"
"}}}
nno  <unique>  [S  5zh
nno  <unique>  ]S  5zl
"               │
"               └ mnemonics: Scroll


" Use `s:default_motions` only to make default motions repeatable.
" Don't use it to make custom motions defined in other plugins repeatable.
" Why?{{{
"
" We're going to invoke `lg#motions_repeatable#main()`.
" The latter  will invoke `s:make_it_repeatable()` for  every motion in
" `s:default_motions`. Suppose we add this dictionary:
"
"     {'bwd': '[z',  'fwd': ']z',  'axis': 1}
"
" The goal would  be to make the  motions `[z` and `]z` (defined in `vim-fold`)
" repeatable. So, here's what will happen:
"
"     ✘
"     if `vim-fold` is sourced AFTER this  plugin, and the `]z` mapping which is
"     defined there  uses `<unique>`,  E227 will  be raised,  because `vim-fold`
"     will try to overwrite the meaning of `]z` given by the current plugin:
"
"             nno ]z <sid>move(']z', 0, 1)
"
"     ✘
"     if `vim-fold` is sourced AFTER this  plugin, and the `]z` mapping which is
"     defined  there does  NOT  use `<unique>`,  `vim-fold`  will overwrite  the
"     meaning of `]z` given by the current plugin (which is not what we we want)
"
"     ✔
"     if `vim-fold`  is sourced BEFORE `vim-repeatable_motion`,  the latter will
"     successfully capture the definition of  `]z` given by `vim-fold`, and will
"     install the necessary wrapper to make it repeatable
"
" Bottom Line:
" For  `]z`  to  keep the  meaning  it  has  in  `vim-fold` AND  be  repeatable,
" we   need  to   make  sure   `lg#motions_repeatable#main()`  is   invoked
" AFTER  `]z`  has  been  defined,  which  can't  be  guaranteed  if  we  invoke
" `lg#motions_repeatable#main()` right now.
"}}}
" How to make a custom motion repeatable then?{{{
"
" In `~/.vim/after/plugin/my_repeatable_motions.vim`, write:
"
"     call lg#motions_repeatable#main(
"     \                     { 'mode': '' ,
"     \                       'buffer': 0,
"     \                       'motions': [
"     \                                    { 'bwd': '<Up>',  'fwd': '<Down>',  'axis': 2 },
"     \                                    { 'bwd': '[z',    'fwd': ']z',      'axis': 1 },
"     \                                    …
"     \                                  ]
"     \                     })
"}}}
" TODO:
" Remove from `s:default_motions` all motions defined somewhere else.
"
" What about `[[`? It's defined somewhere else (after/ftplugin/vim.vim),
" so we should remove it. But if we remove it, we lose the global wrapper.
" We want the global wrapper (could be useful).
"
" Nope:
" `[[` is defined somewhere else, but it's a buffer-local mapping.
" So, we shouldn't remove it from `s:default_motions`, if we want
" the global wrapper.
let s:default_motions = {
\                         'mode': '',
\                         'buffer': 0,
\                         'motions': [
\                                      {'bwd': "['",  'fwd': "]'",  'axis': 1 },
\                                      {'bwd': '(' ,  'fwd': ')' ,  'axis': 1 },
\                                      {'bwd': '[#',  'fwd': ']#',  'axis': 1 },
\                                      {'bwd': '[(',  'fwd': '])',  'axis': 1 },
\                                      {'bwd': '[*',  'fwd': ']*',  'axis': 1 },
\                                      {'bwd': '[/',  'fwd': ']/',  'axis': 1 },
\                                      {'bwd': '[M',  'fwd': ']M',  'axis': 1 },
\                                      {'bwd': '[S',  'fwd': ']S',  'axis': 1 },
\                                      {'bwd': '[[',  'fwd': ']]',  'axis': 1 },
\                                      {'bwd': '[]',  'fwd': '][',  'axis': 1 },
\                                      {'bwd': '[`',  'fwd': ']`',  'axis': 1 },
\                                      {'bwd': '[c',  'fwd': ']c',  'axis': 1 },
\                                      {'bwd': '[m',  'fwd': ']m',  'axis': 1 },
\                                      {'bwd': '[s',  'fwd': ']s',  'axis': 1 },
\                                      {'bwd': '[{',  'fwd': ']}',  'axis': 1 },
\                                      {'bwd': 'g,',  'fwd': 'g;',  'axis': 1 },
\                                      {'bwd': '{' ,  'fwd': '}' ,  'axis': 1 },
\                                    ],
\                       }

" You need to make the default motions repeatable at the very end of the plugin.{{{
"
" In particular, you need  to invoke `s:make_it_repeatable()` AFTER the
" custom fFtT mappings have been installed.
"}}}
" What will happen if you don't? {{{
"
" If you invoke `s:make_it_repeatable()` BEFORE the fFtT mappings,
" `fx` will no longer be repeatable. Why?
"
" Because  then, `s:make_it_repeatable()`  will  fail to  save all  the
" information relative to the `f` mapping inside `s:repeatable_motions`.
" The latter must contain this info, so that `s:move_again()` can retrieve it
" via `s:get_motion_info()`.
"
" FIXME:
" I think  that these 2  comments are  irrelevant. If there are  custom mappings
" whose lhs is `fFtT`, then  they shouldn't be in `s:default_motions` (according
" to the previous fix_me).
"
" Update:
" There's some confusion. The `fFtT` custom mappings defined in another plugin
" should indeed probably be outside `s:default_motions`.
" But the `fFtT` custom mappings defined in this plugin, that's another story…
"}}}
call lg#motions#main#make_repeatable(s:default_motions)
