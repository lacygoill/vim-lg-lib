" Why a guard?{{{
"
" We need to assign values to some variables, for the functions to work.
"
" Big deal … So what?
"
" Rule: Any  interface element  (mapping, autocmd,  command), or  anything which
" initialize the plugin totally or  partially (assignment, call to function like
" `call s:init()`), should be sourced only once.
"
" What's the reasoning behind this rule?
"
" Changing the  state of the plugin  during runtime may have  undesired effects,
" including bugs. Same thing  for the interface.
"}}}
" How could this file be sourced twice?{{{
"
" Suppose you call a function defined in this file from somewhere.
" You write the name of the function correctly, except you make a small typo
" in the last component (i.e. the text after the last #).
"
" Now suppose the file has already been sourced because another function from it
" has been called.
" Later, when Vim  will have to call  the misspelled function, it  will see it's
" not defined.   So, it will look  for its definition. The name  before the last
" component being correct, it will find this file, and source it AGAIN.  Because
" of the typo, it won't find the function,  but the damage is done: the file has
" been sourced twice.
"
" This is unexpected, and we don't want that.
"}}}

if exists('g:autoloaded_lg#motion#repeatable#make')
    finish
endif
let g:autoloaded_lg#motion#repeatable#make = 1

fu! s:init() abort "{{{1
    let s:last_motion = ''

    " database for global motions, which will be populated progressively
    let s:repeatable_motions = []

    let s:KEYCODES = [
        \ '<BS>',
        \ '<Bar>',
        \ '<Bslash>',
        \ '<C-',
        \ '<CR>',
        \ '<Del>',
        \ '<Down>',
        \ '<End>',
        \ '<Esc>',
        \ '<F',
        \ '<Home>',
        \ '<Left>',
        \ '<M-',
        \ '<PageDown>',
        \ '<PageUp>',
        \ '<Plug>',
        \ '<Right>',
        \ '<S-',
        \ '<Space>',
        \ '<Tab>',
        \ '<Up>',
        \ '<lt>',
        \ ]
    let s:KEYCODES = join(s:KEYCODES, '\|')

    let s:DEFAULT_MAPARG = {'buffer': 0, 'expr': 0, 'mode': ' ', 'noremap': 1, 'nowait': 0, 'silent': 0}
    "                                                   Why? ┘{{{
    "
    " This variable will be used to populate information about a built-in motion,
    " for  which  `maparg()`  doesn't  output  anything. We  need  to  choose  a
    " character standing for the default mode we want. As a default mode, I want
    " `nvo`.  For `maparg()`, `nvo` is represented with:
    "
    "     - an empty string in its input
    "     - a single space in its output
    "
    " We need to be consistent with the output of `maparg()`. So, we choose
    " an empty space.
"}}}

    let s:RECURSIVE_MAPCMD = {
    \                          'n': 'nmap',
    \                          'x': 'xmap',
    \                          'o': 'omap',
    \                          '' : 'map',
    \                        }

    let s:NON_RECURSIVE_MAPCMD = {
    \                              'n': 'nnoremap',
    \                              'x': 'xnoremap',
    \                              'o': 'onoremap',
    \                              '' : 'noremap',
    \                            }
endfu
call s:init()

" Core {{{1
fu! s:make_repeatable(m, mode, is_local, from) abort "{{{2
    " can only make ONE motion repeatable

    let bwd_lhs    = a:m.bwd
    let fwd_lhs    = a:m.fwd
    let bwd_maparg = maparg(bwd_lhs, a:mode, 0, 1)
    let fwd_maparg = maparg(fwd_lhs, a:mode, 0, 1)

    " if we ask for a local motion to be made repeatable,
    " the 2 lhs should be used in local mappings
    if    a:is_local
    \ && (!get(bwd_maparg, 'buffer', 0) || !get(fwd_maparg, 'buffer', 0))
        try
            throw 'E8002:  [repeatable motion]  invalid motion: '.a:from
        catch
            return lg#catch_error()
        endtry
    endif

    " Could we install the wrapper mappings BEFORE populating `s:repeatable_motions`?{{{
    "
    " No.
    " It would  cause `s:populate()`  to capture the  definition of  the wrapper
    " mapping instead of the original motion.
    " So, when  we would press  a motion, we would  enter an infinite  loop: the
    " wrapper would call itself again and again, until E132.
    "
    " The fact  that the wrapper  mapping is, by default,  non-recursive doesn't
    " change  anything. When  we  would  press   the  lhs,  Vim  would  evaluate
    " `s:move('lhs')`.
    " At the end, Vim  would compute the keys to press: the  latter would be the
    " output of `s:move('lhs')`. That's  where the recursion comes from. It's
    " like pressing `cd`, where `cd` is defined like so:
    "
    "     nno  <expr>  cd  Func()
    "     fu! Func()
    "         return Func()
    "     endfu
    "}}}

    let origin = matchstr(execute('verb '.a:mode.'no '.(a:is_local ? ' <buffer> ' : '').bwd_lhs),
    \                     '.*\n\s*\zsLast set from.*')
    let motion = {
    \              'made repeatable from': a:from,
    \              'original mapping':     origin,
    \ }
    " Why don't we write an assignment to populate `motion`?{{{
    "
    " `motion` is an array (!= scalar), so Vim passes it to `s:populate()`
    " as a REFERENCE (not as a VALUE), and the function operates in-place.
    " IOW: no need to write:
    "
    "         let motion = s:populate(motion, …)
    "}}}
    call s:populate(motion, a:mode, bwd_lhs, 0, bwd_maparg)
    " now `motion` contains sth like:{{{
    "
    " { 'bwd'    : {'expr': 0, 'noremap': 1, 'lhs': '…', 'mode': ' ', … }}
    "                                                             │
    "                                                             └ nvo
    "}}}
    call s:populate(motion, a:mode, fwd_lhs, 1, fwd_maparg)
    " now `motion` contains sth like:{{{
    "
    " { 'bwd'    : {'expr': 0, 'noremap': 1, 'lhs': '…', 'mode': ' ', … },
    "   'fwd'    : {'expr': 0, 'noremap': 1, 'lhs': '…', 'mode': ' ', … }}
    "}}}

    " Why?{{{
    "
    " `b:repeatable_motions` may not exist. We must make sure it does.
    "
    " I don't want to automatically create it in an autocmd. I only want it
    " if necessary.
    "}}}
    " Ok, but why not `let repeatable_motions = get(b:, 'repeatable_motions', [])` ?{{{
    "
    " It  would  give  us  an  empty  list which  would  NOT  be  the  reference
    " to  `b:repeatable_motions`.    It  would   just  be  an   empty  list.
    "
    " We need  the update the  existing database  of local motions,  not restart
    " from scratch.
    "}}}
    if a:is_local && !exists('b:repeatable_motions')
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
    let repeatable_motions = {a:is_local ? 'b:' : 's:'}repeatable_motions

    if s:collides_with_db(motion, repeatable_motions)
        return
    endif

    call s:install_wrapper(a:mode, a:m, bwd_maparg)

    " add the motion in a db, so that we can retrieve info about it later;
    " in particular its rhs
    call add(repeatable_motions, motion)

    if a:is_local
        " Why?{{{
        "
        " When the filetype plugins are re-sourced (`:e`), Vim removes the local
        " mappings (b:undo_ftplugin). But, our current  plugin hasn't erased the
        " repeatable wrappers from its database (b:repeatable_motions).
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

fu! s:move(lhs) abort "{{{2
    let motion = s:get_motion_info(a:lhs)

    " for some reason, no motion in the db matches `a:lhs`
    if type(motion) !=# type({})
        return ''
    endif

    let dir = s:get_direction(a:lhs, motion)

    " Why don't we translate `a:lhs`?{{{
    "
    " No need to.
    " This function is used in the rhs of wrapper mappings:
    "
    "     exe mapcmd.'  '.a:m.bwd.'  <sid>move('.string(a:m.bwd).')'
    "     exe mapcmd.'  '.a:m.fwd.'  <sid>move('.string(a:m.fwd).')'
    "                                            └─────────────┤
    "                                                          └ automatically translated
    "
    " And mapping commands automatically translate special keys.
    "}}}
    let s:last_motion = a:lhs

    " Why don't we translate the special keys when the mapping uses `<expr>`?{{{
    "
    " Not necessary.
    " Because, the rhs is NOT a keysequence. It's an EXPRESSION.
    " It just needs to be evaluated.
    "
    " Ok, but don't we need to translate special keycodes in the evaluation?
    " Nope.
    " The  evaluation of  the  rhs of  an `<expr>`  mapping  must NEVER  contain
    " special keycodes. The expression must take care of returning feedable keys
    " itself.
    "}}}
    " Why do we need to translate them otherwise?{{{
    "
    " Otherwise, the rhs is NOT fed directly:
    " `:nno` &friends automatically translate any special key it may contain.
    "
    " We need to emulate this behavior, and that's why we invoke `s:translate()`.
    "}}}
    return motion[dir].expr
       \ ?     eval(motion[dir].rhs)
       \ :     s:translate(motion[dir].rhs)
endfu

fu! s:move_again(dir) abort "{{{2
    " This function is called by various mappings whose suffix is `,` or `;`.

    " make sure the arguments are valid,
    " and that we've used at least one motion in the past
    if index(['bwd', 'fwd'], a:dir) == -1 || empty(s:last_motion)
        return ''
    endif

    let motion = s:get_motion_info(s:last_motion)
    " How could we get an unrecognized motion?{{{
    "
    " You have a motion defined in a given mode.
    " But `s:move_again()` is invoked to repeat it in a different mode.
    "
    " Or:
    " The last motion is  local to a buffer, you change the  buffer, and in this
    " one the motion doesn't exist…
    "}}}
    if type(motion) !=# type({})
        return ''
    endif

    " What does this variable mean?{{{
    "
    " It's a numeric flag, whose value can be:
    "
    "       ┌────┬───────────────────────────────────────────┐
    "       │ 0  │ we are NOT going to repeat a motion       │
    "       ├────┼───────────────────────────────────────────┤
    "       │ -1 │ we are about to repeat a motion BACKWARDS │
    "       ├────┼───────────────────────────────────────────┤
    "       │ 1  │ we are about to repeat a motion FORWARDS  │
    "       └────┴───────────────────────────────────────────┘
    "}}}
    " Why do we set it now?{{{
    "
    " Suppose we've pressed `fx`, and now we want to repeat it with `;`.
    " In this case:
    "
    "     motion[a:dir].expr  =  1
    "     motion[a:dir].rhs   =  <sid>fts()
    "                                 │
    "                                 └ custom function defined in another script
    "
    " The code in `s:fts()` is going to be evaluated, and the result typed as keys.
    " But, `s:fts()` needs to know whether we are pressing `f` to ask for a target,
    " or repeating a previous `fx`:
    "
    "     if lg#motion#repeatable#make#is_repeating()
    "        " repeat last `fx`
    "         …
    "     else
    "        " ask for a target, then press `f{target}`
    "         …
    "     endif
    "}}}
    let s:is_repeating_motion = a:dir is# 'fwd' ? 1 : -1

    " Why not returning the sequence of keys directly?{{{
    "
    " The original  motion could be  silent or recursive; blindly  returning the
    " keys could alter these properties.
    "
    " As an  example, the  ; ,  z; z,  mappings are  non-recursive (`:noremap`),
    " because that's what we want by default.  However, for some motions, we may
    " need recursiveness.
    "
    " Example: `]e` to move the line down.
    "
    " Therefore, if we  returned the sequence directly, it  wouldn't be expanded
    " even when  it needs  to be. So,  we use  `feedkeys()` to  write it  in the
    " typeahead  buffer  recursively or  non-recursively  depending  on how  the
    " original motion was defined.
    "
    " And if the  original mapping was silent, the wrapper should be too.
    " IOW, if the rhs is an Ex command, it shouldn't be displayed on the command
    " line.
    "}}}
    " To emulate `<silent>`, why not simply `:redraw!`?{{{
    "
    "     - overkill
    "
    "     - If  the  motion  wants  to  echo   a  message,  it  will
    "       probably  be erased. That's not what <silent> does.  <silent>
    "       only prevents the rhs from being  echo'ed. But it can still
    "       display  a message  if it wants to.
    "
    "     - Sometimes, the command-line may seem to flash.
    "       Currently,  it  happens when  we  cycle  through the  levels  of
    "       lightness of the colorscheme (]oL  co;  ;).
    "}}}
    " Why do we need to replace `|` with `<bar>`?{{{
    "
    " We're going to install a mapping. `|` would wrongly end the rhs.
    "}}}
    " Where could this bar come from?{{{
    "
    " From the database of repeatable motions, whose information, including
    " the rhs, is obtained with `maparg()`.
    "}}}
    exe s:get_current_mode().(!motion[a:dir].noremap ? 'map' : 'noremap')
    \   .(motion[a:dir].nowait ? '  <nowait>' : '')
    \   .(motion[a:dir].expr   ? '  <expr>'   : '')
    \   .(motion[a:dir].silent ? '  <silent>' : '')
    \   .'  <plug>(repeat-motion-tmp)'
    \   .'  '.substitute(motion[a:dir].rhs, '|', '<bar>', 'g')

    call feedkeys("\<plug>(repeat-motion-tmp)", 'i')
    "                                            │
    "                                            └ `<plug>(…)`, contrary to `seq`, must ALWAYS
    "                                              be expanded so don't add the 'n' flag

    " Why do we reset all these variables?{{{
    "
    " It's for  a custom function which  we could define to  implement a special
    " motion like `fFtTssSS`. Similar to what we have to do in `s:fts()`.
    "
    " `tTfFssSS` are  special because  the lhs, which  is saved  for repetition,
    " doesn't  contain the  necessary  character  which must  be  passed to  the
    " command. IOW, when the last motion was `fx`, `f` is insufficient to know
    " where to move.
    "}}}
    call timer_start(0, {-> execute('let s:is_repeating_motion = 0')})

    " If we're using  `]q` &friends, we need to redraw  all statuslines, so that
    " the position in the list is updated immediately.
    "
    " TODO:
    " It was needed in the past, but it's not anymore.
    " Because we execute  `:redraw` via `vim-submode`, which  redraws the screen
    " AND the  statuslines. However, if we eliminate  `:redraw` later, uncomment
    " the next line.
    "
    "     call timer_start(0, { -> execute('redraws!') })

    return ''
endfu

fu! s:populate(motion, mode, lhs, is_fwd, maparg) abort "{{{2
    let dir = a:is_fwd ? 'fwd' : 'bwd'

    " make a custom mapping repeatable
    if !empty(a:maparg)
        let a:motion[dir] = a:maparg
        " Why?{{{
        "
        " `a:maparg` was obtained via `maparg()`.
        " The latter automatically translates `<C-j>` into `<NL>`.
        " This will break mappings whose lhs contains `<C-j>` (e.g. `z C-j`).
        "}}}
        if a:motion[dir].lhs =~# '\C<NL>'
            let a:motion[dir].lhs =
            \       substitute(a:motion[dir].lhs, '\C<NL>', "\<c-j>", 'g')
        endif
        if a:motion[dir].rhs =~# '\c<sid>'
            let a:motion[dir].rhs =
            \       substitute(a:motion[dir].rhs, '\c<sid>', '<snr>'.a:motion[dir].sid.'_', 'g')
        endif

    " make a built-in motion repeatable
    else
        let a:motion[dir] = extend(deepcopy(s:DEFAULT_MAPARG),
        \                          {'mode': empty(a:mode) ? ' ' : a:mode })
        "                                Why? ┘{{{
        "
        " Because if `maparg()`  doesn't give any info, we want  to fall back on
        " the mode `nvo`. And  to be consistent, we want to  populate our motion
        " with exactly  the same info that  `maparg()` would give for  `nvo`: an
        " empty space.
        "
        " So, if we initially passed the mode '' when we invoked the function to
        " make some motions repeatable,  we now want to use '  ' to populate the
        " database of repeatable motions.
        "
        " This inconsistency between '' and ' ' mimics the one found in `maparg()`.
        " For `maparg()`, `nvo` is represented with:
        "
        "     - an empty string in its input
        "     - a single space in its output
        "}}}
        let a:motion[dir].lhs = a:lhs
        let a:motion[dir].rhs = a:lhs
    endif

    " we save the lhs keysequence, unmodified, so that `:RepeatableMotions`
    " has something readable to display
    let a:motion[dir].untranslated_lhs = a:motion[dir].lhs

    " We now translate it to normalize its form.
    " Why?{{{
    "
    " `a:motion[dir].lhs` comes from `lg#motion#repeatable#make#all()`.
    " Its form depends on how the user wrote the motion.
    " Example:
    "             Z<c-l>
    "             Z<C-L>
    "
    " … are different, but both describe the same keysequence.
    "
    " This difference  may cause an  issue later,  when we make  some comparison
    " between the lhs of a motion and some keysequence.
    " We must make sure, we're always comparing the same (translated) form.
    "}}}
    let a:motion[dir].lhs = s:translate(a:motion[dir].lhs)
endfu
" }}}1
" Interface {{{1
fu! lg#motion#repeatable#make#all(what) abort "{{{2
    " can make several motions repeatable

    " sanitize input
    if sort(keys(a:what)) !=# ['buffer', 'from', 'mode', 'motions']
        try
            throw 'E8000:  [repeatable motion]  missing key'
        catch
            return lg#catch_error()
        endtry
    endif

    " Make the motions repeatable{{{
    "
    " We need to install a wrapper mapping  around each motion, to save the last
    " used one.  Otherwise, how the repeating mappings would know what motion to
    " repeat?
    "
    " We also need a database of repeatable motions, with all their information.
    " Otherwise,  how  the repeating  mappings  would  be  able to  emulate  the
    " original motion?
    "}}}
    let mode     = a:what.mode
    let is_local = a:what.buffer
    let from     = a:what.from
    for m in a:what.motions
        " Warning `execute()` is buggy in Neovim{{{
        "
        " It sometimes fail to capture anything. It  has been fixed in a Vim
        " patch.  For this code to work in  Neovim, you need to wait for the
        " patch to be merged there, or use `:redir`.
       "}}}
        " Why this check?{{{
        "
        " If  the motion  is global,  one  of its  lhs  could be  shadowed by  a
        " buffer-local  mapping using  the same  lhs. We handle  this particular
        " case by temporarily removing the latter.
        "}}}
        if !is_local && (     execute(mode.'map <buffer> '.m.bwd) !~# '^\n\nNo mapping found$'
                         \ || execute(mode.'map <buffer> '.m.fwd) !~# '^\n\nNo mapping found$')
            let map_save = s:unshadow(m, mode)
            call s:make_repeatable(m, mode, is_local, from)
            call lg#map#restore(map_save)
        else
            call s:make_repeatable(m, mode, is_local, from)
        endif
    endfor

    " if not already done, install the `,` and `;` mappings to repeat the motions
    if maparg(',') !~# 'move_again('
        let mapcmd = mode.'noremap'
        exe mapcmd." <expr> , <sid>move_again('bwd')"
        exe mapcmd." <expr> ; <sid>move_again('fwd')"
    endif
endfu

fu! lg#motion#repeatable#make#set_last_used(lhs) abort "{{{2
    let s:last_motion = s:translate(a:lhs)
endfu
" }}}1
" Misc. {{{1
fu! s:collides_with_db(motion, repeatable_motions) abort "{{{2
    " Purpose:{{{
    " Detect whether the motion we're trying  to make repeatable collides with
    " a motion in the db.
    "}}}
    " When does a collision occur?{{{
    "
    " When `a:motion` is already in the db (TOTAL collision).
    " Or when a motion in the db has the same mode as `a:motion`, and one of its
    " `lhs` key has the same value as one of `a:motion` (PARTIAL collision).
    "}}}
    " Why is a collision an issue?{{{
    "
    " If you try to install a wrapper around a key which has already been wrapped,
    " you'll probably end up losing the original definition:
    " in the db, it may be replaced with the one of the 1st wrapper.
    "
    " Besides:
    " Vim shouldn't make a motion repeatable twice (total collision):
    "
    "     Because it means we have a useless invocation of
    "     `lg#motion#repeatable#make#all()`
    "     somewhere in our config, it should be removed.
    "
    " Vim shouldn't change the motion to which a lhs belongs (partial collision):
    "
    "     we make this motion repeatable:    [m  ]m  (normal mode)    ✔
    "     "                             :    [m  ]]  (normal mode)    ✘
    "
    "     We probably have made an error. We should be warned to fix it.
    "}}}

    "   ┌ Motion
    "   │
    for m in a:repeatable_motions
        if   [m.bwd.lhs, m.bwd.mode] ==# [a:motion.bwd.lhs, a:motion.bwd.mode]
        \ || [m.fwd.lhs, m.fwd.mode] ==# [a:motion.fwd.lhs, a:motion.fwd.mode]
            try
                throw printf('E8003:  [repeatable motion]  cannot process motion  %s : %s',
                \             m.bwd.lhs, m.fwd.lhs)
            catch
                call lg#catch_error()
            finally
                return 1
            endtry
        endif
    endfor
    return 0
endfu

fu! s:get_current_mode() abort "{{{2
    " Why the substitutions?{{{
    "
    "     substitute(mode(1), "[vV\<c-v>]", 'x', ''):
    "
    "         normalize output of `mode()` to match the one of `maparg()`
    "         in case we're in visual mode
    "
    "     substitute(…, 'no', 'o', '')
    "
    "         same thing for operator-pending mode
    "}}}
    return substitute(substitute(mode(1), "[vV\<c-v>]", 'x', ''), 'no', 'o', '')
endfu

fu! s:get_direction(lhs, motion) abort "{{{2
    "            ┌ no need to translate: it has been translated in a mapping
    "            │         ┌ no need to translate: it has been translated in `s:populate()`
    "            │         │
    let is_fwd = a:lhs is# a:motion.fwd.lhs
    return is_fwd ? 'fwd' : 'bwd'
endfu

fu! s:get_mapcmd(mode, maparg) abort "{{{2
    "                  ┌ the value of the 'noremap' key stands for the NON-recursiveness
    "                  │ but we want a flag standing for the recursiveness
    "                  │ so we need to invert the value of the key
    "                  │
    let is_recursive = !get(a:maparg, 'noremap', 1)
    "                                            │
    "                                            └ by default, we don't want
    "                                              a recursive wrapper mapping

    let mapcmd = s:{is_recursive ? '' : 'NON_'}RECURSIVE_MAPCMD[a:mode]

    let mapcmd .= '  <expr>'

    let mapcmd .= join(map(['buffer', 'nowait', 'silent'],
    \                      {_,v -> get(a:maparg, v, 0) ? '<'.v.'>' : ''}))

    return mapcmd
endfu

fu! s:get_motion_info(lhs) abort "{{{2
    " Purpose:{{{
    " return the info about the motion in the db:
    "
    "     - which contains `a:lhs` (no matter for which direction)
    "     - whose mode is the identical to the one in which we currently are
    "}}}

    let mode = s:get_current_mode()
    let motions = get(maparg(a:lhs, mode, 0, 1), 'buffer', 0)
              \ ?     get(b:, 'repeatable_motions', [])
              \ :     s:repeatable_motions

    for m in motions
        " Why don't you translate `a:lhs` to normalize it?{{{
        "
        " No need to.
        "
        " The current function is called from:
        "
        "     - s:move()
        "     - s:move_again()
        "
        " In `s:move()`, `s:get_motion_info()` is passed a keysequence which has
        " been translated automatically  because `s:move()` was in the  rhs of a
        " mapping.
        "
        " In  `s:move_again()`, `s:get_motion_info()`  is  passed a  keysequence
        " from `s:last_motion`.
        " All the keysequences inside this dictionary are set by:
        "
        "     lg#motion#repeatable#make#set_last_used()
        "
        " And the latter translates every keysequence it receives.
        "}}}
        " Same question for `m.bwd.lhs` and `m.fwd.lhs`?{{{
        "
        " No need to.
        " We've done it already in `s:populate()`.
        "}}}
        if   index([m.bwd.lhs, m.fwd.lhs], a:lhs) >= 0
        \ && index([mode, ' '], m.bwd.mode) >= 0
        "                      └────────┤
        "                               └ mode of the motion:
        "                                 originally obtained with `maparg()`
        "
        " Why this last condition? {{{
        "
        " We only pass a lhs to  this function. So, without this condition, when
        " the function would  try to find the relevant info  in the database, it
        " wouldn't care about the mode of the motion.
        " It would  stop searching as  soon as it would  find one which  has the
        " right lhs.  It's wrong; it should also care about the mode.
        "
        " Here's what could happen:
        "
        "     1. go to a function containing a `:return` statement
        "     2. enter visual mode
        "     3. press `%` on `fu!`
        "     4. press `;`
        "     5. press Escape
        "     6. press `;`
        "
        " Now `;` makes us enter visual  mode. It shouldn't. We want a motion in
        " normal mode.
        "}}}
        " Why a single space?{{{
        "
        " `m.bwd.mode` could  be a  space, if the  original mapping  was defined
        " with `:noremap` or  `:map`. But `mode` will never be  a space, because
        " it gets its value from `mode(1)`, which will return:
        "
        "     'n', 'v', 'V', 'C-v' or 'no'
        "
        " So, we need to compare `m.bwd.mode` to the current mode, AND to a space.
        "}}}
        " Note that there's an inconsistency in  maparg(){{{
        "
        " Don't be confused:
        "
        " if you want information about a mapping in the 3 modes `nvo`, the help
        " says that you must  pass an empty string as the  2nd argument.  But in
        " the output, they will be represented  with a single space, not with an
        " empty string.
        "}}}
        " There's also one between  maparg()  and  mode(){{{
        "
        " To express  the operator-pending mode,  `maparg()` expects 'o'  in its
        " input, while `mode(1)` uses 'no' in its output.
        "}}}
            return m
        endif
    endfor
endfu

fu! s:install_wrapper(mode, m, maparg) abort "{{{2
    let mapcmd = s:get_mapcmd(a:mode, a:maparg)
    exe mapcmd.'  '.a:m.bwd.'  <sid>move('.string(a:m.bwd).')'
    exe mapcmd.'  '.a:m.fwd.'  <sid>move('.string(a:m.fwd).')'
endfu

fu! lg#motion#repeatable#make#is_repeating() abort "{{{2
    return get(s:, 'is_repeating_motion', 0)
endfu

fu! lg#motion#repeatable#make#share_env() abort "{{{2
    return s:repeatable_motions
endfu

fu! s:translate(seq) abort "{{{2
    " Purpose:{{{
    " When  we  populate  the  database   of  repeatable  motions,  as  well  as
    " `s:last_motion`,  we   need  to   get  a  normalized   form  of   the  lhs
    " keysequence(s).  So that future comparisons are reliable.
    "
    " For more info, see the comment at the end of `s:populate()`.
    "
    " Also:
    " The keysequence  returned by `s:move()`  is directly fed to  the typeahead
    " buffer. If it contains special keycodes, they must be translated.
    "}}}
    return eval('"'.substitute(escape(a:seq, '"\'), '\m\c\ze\%('.s:KEYCODES.'\)', '\\', 'g').'"')
    "                                         ││
    "                                         │└ to prevent a real backslash contained in the sequence
    "                                         │  from being removed by `eval("…")`
    "                                         │
    "                                         └ to not break the string passed to `eval()` prematurely
endfu

fu! s:unshadow(m, mode) abort "{{{2
    let map_save = lg#map#save(a:mode, 1, [a:m.bwd, a:m.fwd])
    exe 'sil! '.a:mode.'unmap <buffer> '.a:m.bwd
    exe 'sil! '.a:mode.'unmap <buffer> '.a:m.fwd
    return map_save
endfu

fu! s:update_undo_ftplugin() abort "{{{2
    if stridx(get(b:, 'undo_ftplugin', ''), 'unlet! b:repeatable_motions') ==# -1
        let b:undo_ftplugin = get(b:, 'undo_ftplugin', 'exe')
            \ . ' | unlet! b:repeatable_motions'
    endif
endfu
