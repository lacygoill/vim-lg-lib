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
    let s:repeatable_motions = []
    let s:last_motions = {}
    let s:is_repeating_motion = {}

    let s:DEFAULT_MAPARG = {'buffer': 0, 'expr': 0, 'mode': ' ', 'noremap': 1, 'nowait': 0, 'silent': 0}
    "                                                   Why? ┘{{{
    "
    " This variable will be used to populate information about a default motion,
    " for  which  `maparg()`  doesn't  output  anything. We  need  to  choose  a
    " character standing for the default mode we want. As a default mode, I want
    " `nvo`.  For `maparg()`, `nvo` is represented with:
    "
    "     • an empty string in its input
    "     • a single space in its output
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
fu! s:install_wrapper(mode, m, maparg) abort "{{{2
    let mapcmd = s:get_mapcmd(a:mode, a:maparg)
    exe mapcmd.'  '.a:m.bwd.'  <sid>move('.string(a:m.bwd).', '.get(a:maparg, 'buffer', 0).', 1)'
    exe mapcmd.'  '.a:m.fwd.'  <sid>move('.string(a:m.fwd).', '.get(a:maparg, 'buffer', 0).', 1)'
endfu

fu! s:make_each_repeatable(mode, is_local, m, axis, from) abort "{{{2
    " can make only ONE motion repeatable

    let bwd    = a:m.bwd
    let fwd    = a:m.fwd
    let bwd_maparg = maparg(bwd, a:mode, 0, 1)
    let fwd_maparg = maparg(fwd, a:mode, 0, 1)

    " if we ask for a local motion to be made repeatable,
    " the 2 lhs should be used in local mappings
    if a:is_local
                  \&& (    !get(bwd_maparg, 'buffer', 0)
                       \|| !get(fwd_maparg, 'buffer', 0))
        try
            throw 'E8002:  [repeatable motion]  invalid motion: '.a:from
        catch
            return lg#catch_error()
        endtry
    endif

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

    let motion = { 'axis': a:axis,
    \              'made repeatable from': a:from,
    \              'original mapping': matchstr(
    \                                           execute('verb '.a:mode.'no '.(a:is_local ? ' <buffer> ' : '').bwd),
    \                                           '.*\n\s*\zsLast set from.*') }
    " Why don't we write an assignment to populate `motion`?{{{
    "
    " `motion` is an array (!= scalar), so Vim passes it to `s:populate()`
    " as a REFERENCE (not as a VALUE), and the function operates in-place.
    " IOW: no need to write:
    "
    "         let motion = s:populate(motion, …)
    "}}}
    call s:populate(motion, a:mode, bwd, 0, bwd_maparg)
    " `motion` value is now sth like:{{{
    "
    " { 'axis' : ', ;',
    "   'bwd'    : {'expr': 0, 'noremap': 1, 'lhs': '…', 'mode': ' ', … }}
    "                                                             │
    "                                                             └ nvo
    "}}}
    call s:populate(motion, a:mode, fwd, 1, fwd_maparg)
    " `motion` value is now sth like:{{{
    "
    " { 'axis' : ', ;',
    "   'bwd'    : {'expr': 0, 'noremap': 1, 'lhs': '…', 'mode': ' ', … },
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
        " MWE:
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

fu! s:move(lhs, buffer, update_last_motion, ...) abort "{{{2
    " What is the purpose of this optional argument?{{{
    "
    " When  `s:move_again()` is  invoked,  it calls  `s:move()`,  and passes  an
    " additional dictionary argument. The latter  contains all information about
    " the motion to repeat. It also contains the key 'no translation'.
    "
    " The  info  about  the  motion   are  not  necessary:  we  could  re-invoke
    " `s:get_motion_info()`. But it  wouldn't be optimal. We've  already compute
    " the info; there's no need to do it twice.
    "
    " The value of the key 'no translation' is a boolean flag.
    " When it's on, it means we  don't want `s:move()` to translate special keys
    " at  the  end. This  matters  for  the  `<plug>`  key.
    "}}}

    let motion = a:0 ? a:1 : s:get_motion_info(a:lhs)
    if type(motion) != type({})
        return ''
    endif

    " Why this check?{{{
    "
    " To be efficient. There's no need to always update the last motion.
    "}}}
    " When is it useless to update last motion?{{{
    "
    " `s:move()` is called  by `move_again()` to know which keys  to type when
    " we press `;`  (&friends).  When that happens, we don't  need to update the
    " last motion: it didn't change. Only the  direction may change, but not the
    " motion.
    "
    " So we pass a zero flag as the last argument for `s:move()` when we call it
    " from `move_again()`. The  rest of the  time, in the wrappers  around the
    " motions, we pass a zero flag.
    "}}}
    if a:update_last_motion
        " Why don't we translate `a:lhs`?{{{
        "
        " There's probably no need to.
        " This function is called at the beginning of `s:move()`.
        " The  latter passes  to it  a keysequence,  which originally  comes from  a
        " mapping. And Vim automatically translates special keys in a mapping.
        "
        "     mapping → s:move(lhs, …)
        "     │                │
        "     │                └ result of the previous translation
        "     │
        "     └ automatically translates special keys
        "}}}
        let s:last_motions[motion.axis] = a:lhs
    endif

    let dir_key = s:get_direction(a:lhs, motion)
    if empty(dir_key)
        return ''
    endif

    let is_expr_mapping = motion[dir_key].expr
    if motion[dir_key].rhs =~# '\c<sid>'
        let motion[dir_key].rhs =
        \    substitute(motion[dir_key].rhs, '\c<sid>', '<snr>'.motion[dir_key].sid.'_', 'g')
    endif

    " Why don't we translate the special keys when the mapping uses `<expr>`?{{{
    "
    " I don't think there's a need to invoke `s:make_keys_feedable()` when the
    " original mapping uses `<expr>`.
    "
    " Because, the rhs is an EXPRESSION whose value is keys which will be FED
    " directly to the typeahead buffer.
    "}}}
    " Why don't we translate them when the function received an optional argument?{{{
    "
    " When `s:move()` is called from a  wrapper, the keys are directly typed. In
    " this case, `<plug>` must be translated.
    "
    " But when `s:move()` is called  from `s:move_again()`, and the latter can't
    " type the  keys directly  because the  original motion  is silent,  it must
    " install a temporary mapping. Something like:
    "
    "     nmap  <plug>(repeat-silently)  rhs_containing_a_plug
    "                                                     ^
    "                                                     must NOT be translated
    "
    " We  won't   be  able  to  install   it  properly  if  `<plug>`   has  been
    " translated. The rhs will be wrong, and  I can't undo the translation, even
    " with a substitution.
    "}}}
    " Why do we need to translate them in the other cases?{{{
    "
    " In the other cases, the rhs is NOT fed directly:
    " Vim translates automatically any special key it may contain.
    "
    " We need to emulate this behavior, and that's why we invoke
    " `s:make_keys_feedable()`.
    "}}}
    return is_expr_mapping
    \?         eval(motion[dir_key].rhs)
    \:         a:0 && a:1['no translation']
    \?             motion[dir_key].rhs
    \:             s:make_keys_feedable(motion[dir_key].rhs)
endfu

fu! s:move_again(dir, axis) abort "{{{2
    " This function is called by various mappings whose suffix is `,` or `;`.

    " make sure the arguments are valid,
    " and that we've used at least one motion on the axis
    if  s:invalid_axis_or_direction(a:axis, a:dir)
    \|| empty(get(s:last_motions, a:axis, ''))
        return ''
    endif

    " get last motion on the axis provided
    let motion = s:get_motion_info(s:last_motions[a:axis])

    " How could we get an unrecognized motion?{{{
    "
    " You have a motion defined in a given mode.
    " You've invoked the function to repeat it in a different mode.
    "
    " Another possibility:
    " The last motion is  local to a buffer, you change the  buffer, and in this
    " one the motion doesn't exist…
    "}}}
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
    "     fts('f')
    "
    " And the code in `fts()` IS influenced by:
    "
    "     s:is_repeating_motion[', ;']
    "}}}
    let s:is_repeating_motion[a:axis] = a:dir ==# 'fwd' ? 1 : -1

    let is_silent = motion[a:dir].silent
    let seq = call('s:move',   [motion[a:dir].lhs, motion[a:dir].buffer, 0]
    \                        + [extend(motion, {'no translation': is_silent ? 1 : 0})])
    "                                                                         │
    "                                           don't translate special keys: ┘
    "
    "                        we're going to install a temporary mapping (because
    "                        the motion must be silent), so `<plug>` must NOT be
    "                        translated

    " Why do we reset all these variables?{{{
    "
    " I think it's  for a custom function  which we could define  to implement a
    " special motion like `fFtTssSS`. Similar to what we have to do in `fts()`.
    "
    " `tTfFssSS` are  special because  the lhs, which  is saved  for repetition,
    " doesn't  contain the  necessary  character  which must  be  passed to  the
    " command. IOW, when the last motion was `fx`, `f` is insufficient to know
    " where to move.
    "
    " Note that `fFtTssSS` are specific to the  axis `, ;`, but we could want to
    " define special  motions on other  axes. That's why,  we need to  reset ALL
    " variables.
    "}}}
    call map(s:is_repeating_motion, {i,v -> 0})

    " If we're using  `]q` &friends, we need to redraw  all statuslines, so that
    " the position in the list is updated immediately.
    "
    " TODO:
    " It was needed in the past, but it's not anymore.
    " Because we execute  `:redraw` via `vim-submode`, which  redraws the screen
    " AND the statuslines. However,  if we get rid of `:redraw`  later, uncomment
    " the next 3 lines.
    "
    "     if a:axis ==# 'z, z;'
    "         call timer_start(0, {-> execute('redraws!')})
    "     endif

    " How could it be empty?{{{
    "
    " The rhs of the motion could be an expression returning an empty string.
    " But during its evaluation, Vim would have to invoke `feedkeys()`.
    " That's a mechanism we may sometimes need to use.
    "}}}
    " If it's empty, then is the repetition of the motion broken?{{{
    "
    " No. In this particular case, the original code implementing the motion has
    " already invoked `feedkeys()`. We don't need to re-invoke it here.
    " And we  can't anyway. We don't know  what the original code  does: what it
    " passes to `feedkeys()`. It doesn't matter. The motion is fine.
    "}}}
    " Why return only now, and not as soon as we get `seq`? {{{
    "
    " Before returning, we must make sure to properly reset `s:is_repeating_motion[…]`
    " Otherwise it would break the repeatibility of some motions, like `fx` &friends.
    " We probably also need to redraw the statusline for `]q` &friends.
    "
    " Bottom Line:
    " Even if `seq` is empty, return as late as possible.
    "}}}
    " What happens if we don't return?{{{
    "
    " Nothing. But if the original motion was  silent, the next block of code is
    " going  to  try  to  install  a temporary  mapping. It  will  be  correctly
    " installed, but will have no rhs. So, when we'll repeat the motion, we'll
    " see the message:
    "
    "     No mapping found
    "
    " Also, for some reason, the repetition seems to be broken. Probably because
    " of  the previous  error. Vim  must  stop processing  the  mapping when  it
    " encounters it.
    "}}}
    if empty(seq)
        return ''
    endif

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
    let is_recursive = !motion[a:dir].noremap

    if is_silent
        " Why installing a mapping? Why not simply `:redraw!`?{{{
        "
        "     • overkill
        "
        "     • If  the  motion  wants  to  echo   a  message,  it  will
        "       probably  be erased. That's not what <silent> does.  <silent>
        "       only prevents the rhs from being  echo'ed. But it can still
        "       display  a message  if it wants to.
        "
        "     • Sometimes, the command line may seem to flash.
        "       Currently,  it  happens when  we  cycle  through the  levels  of
        "       lightness of the colorscheme (]oL  co;  ;).
        "}}}
        " Why do we need to replace `|` with `<bar>`?{{{
        "
        " We're going to install a mapping. `|` would wrongly end the rhs.
        "}}}
        " Where could this bar come from?{{{
        "
        " `s:move()`, called when we got `seq`.
        "}}}
        exe s:get_current_mode().(is_recursive ? 'map' : 'noremap')
        \   .'  <silent>'
        \   .'  <plug>(repeat-silently)'
        \   .'  '.substitute(seq, '|', '<bar>', 'g')
        call feedkeys("\<plug>(repeat-silently)", 'i')
        "                                          │
        "                                          └ `<plug>(…)`, contrary to `seq`, must ALWAYS
        "                                            be expanded so don't add the 'n' flag
    else
        call feedkeys(seq, 'i'.(is_recursive ? '' : 'n'))
    endif
    return ''
endfu

fu! s:populate(motion, mode, lhs, is_fwd, maparg) abort "{{{2
    let dir = a:is_fwd ? 'fwd' : 'bwd'

    " make a custom mapping repeatable
    if !empty(a:maparg)
        let a:motion[dir] = a:maparg
    " make a default motion repeatable
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
        "     • an empty string in its input
        "     • a single space in its output
        "}}}
        let a:motion[dir].lhs = a:lhs
        let a:motion[dir].rhs = a:lhs
    endif
endfu

fu! lg#motion#repeatable#make#share_env() abort "{{{2
    return s:repeatable_motions
endfu

fu! s:update_undo_ftplugin() abort "{{{2
    if stridx(get(b:, 'undo_ftplugin', ''), 'unlet! b:repeatable_motions') == -1
        let b:undo_ftplugin =          get(b:, 'undo_ftplugin', '')
        \                     . (empty(get(b:, 'undo_ftplugin', '')) ? '' : '|')
        \                     . 'unlet! b:repeatable_motions'
    endif
endfu

" Interface {{{1
fu! lg#motion#repeatable#make#all(what) abort "{{{2
    " can make several motions repeatable

    " sanitize input
    if sort(keys(a:what)) !=# ['axis', 'buffer', 'from', 'mode', 'motions']
        try
            throw 'E8000:  [repeatable motion]  missing key'
        catch
            return lg#catch_error()
        endtry
    endif

    " build a name matching the axis:
    "
    "     'axis': {'bwd': 'z,', 'fwd': 'z;'}
    "     →
    "     'z, z;'
    if has_key(a:what.axis, 'bwd') && has_key(a:what.axis, 'fwd')
        let axis = a:what.axis.bwd.' '.a:what.axis.fwd
    else
        try
            throw 'E8001:  [repeatable motion]  missing key'
        catch
            return lg#catch_error()
        endtry
    endif

    if  maparg(a:what.axis.bwd) !~# 'move_again('
        " What command do you use to install the mappings repeating motions?{{{
        "
        " By  default, we  use `:noremap`.   However,  if the  user invoked  the
        " function  by  adding  the  optional  key  'mode',  in  the  dictionary
        " `a:what.axis`, we take it into consideration.
        " So:
        "
        "     'axis':  {'bwd': 'z,', 'fwd': 'z;'}
        "         → noremap
        "
        "     'axis':  {'bwd': 'z,', 'fwd': 'z;', 'n'}
        "         → nnoremap
        "}}}
        let mapcmd = get(a:what.axis, 'mode', '') == ''
        \?               'noremap'
        \:               a:what.axis.mode . 'noremap'
        exe mapcmd.'  <expr>  '.a:what.axis.bwd."  <sid>move_again('bwd', ".string(axis).')'
        exe mapcmd.'  <expr>  '.a:what.axis.fwd."  <sid>move_again('fwd', ".string(axis).')'

        " We also install <plug> mappings  to be able to access `s:move_again()`
        " from another script.
        " When the axis  contains `z,` and `z;`, these mappings  could be useful
        " to create a submode in which we don't have to press `z`.
        exe mapcmd.'  <expr>  <plug>(backward-'.substitute(axis, '\s\+', '_', 'g').")  <sid>move_again('bwd', ".string(axis).')'
        exe mapcmd.'  <expr>  <plug>(forward-' .substitute(axis, '\s\+', '_', 'g').")  <sid>move_again('fwd', ".string(axis).')'
    endif

    let from     = a:what.from
    let mode     = a:what.mode
    let is_local = a:what.buffer
    " try to make all the motions received repeatable
    for m in a:what.motions
        " Warning: `execute()` is buggy in Neovim{{{
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
        if !is_local && (    execute(mode.'map <buffer> '.m.bwd) !~# '^\n\nNo mapping found$'
                         \|| execute(mode.'map <buffer> '.m.fwd) !~# '^\n\nNo mapping found$')
            let map_save = s:unshadow(m, mode)
            call s:make_each_repeatable(mode, is_local, m, axis, from)
            call lg#map#restore(map_save)
        else
            call s:make_each_repeatable(mode, is_local, m, axis, from)
        endif
    endfor
endfu

fu! lg#motion#repeatable#make#set_last_used(lhs,axis) abort "{{{2
    let s:last_motions[join(values(a:axis))] = s:translate_lhs(a:lhs)
endfu

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
    " in the db, it may be replaced with the 1st wrapper.
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
    "     we define the motion:    [m  ]m  (normal mode)    ✔
    "     we define the motion:    [m  ]]  (normal mode)    ✘
    "
    "     We probably have made an error. We should be warned to fix it.
    "}}}

    "   ┌ Motion
    "   │
    for m in a:repeatable_motions
        if  a:motion.bwd.lhs ==# m.bwd.lhs && a:motion.bwd.mode ==# m.bwd.mode
        \|| a:motion.fwd.lhs ==# m.fwd.lhs && a:motion.fwd.mode ==# m.fwd.mode
            try
                throw printf("E8003:  [repeatable motion]  cannot process motion '%s : %s'",
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

fu! s:get_direction(lhs, motion) abort "{{{2
    let is_fwd = s:translate_lhs(a:lhs) ==# s:translate_lhs(a:motion.fwd.lhs)
    return is_fwd ? 'fwd' : 'bwd'
endfu

fu! s:get_mapcmd(mode, maparg) abort "{{{2
    let is_recursive = !get(a:maparg, 'noremap', 1)
    "                                            │
    "                                            └ by default, we don't want
    "                                              a recursive wrapper mapping

    let mapcmd = s:{is_recursive ? '' : 'NON_'}RECURSIVE_MAPCMD[a:mode]

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

fu! s:get_motion_info(lhs) abort "{{{2
    " Purpose:{{{
    " return the info about the motion in the db which:
    "
    "     • contains `a:lhs` (no matter for which direction)
    "     • has the same mode as the current one
    "}}}
    " Why don't you check the axis too?{{{
    "
    " Because, in practice, it doesn't make much sense to repeat the same
    " motion on 2 axes.
    "}}}

    let mode = s:get_current_mode()
    let motions = get(maparg(a:lhs, mode, 0, 1), 'buffer', 0)
    \?                get(b:, 'repeatable_motions', [])
    \:                s:repeatable_motions

    for m in motions
        if  index([s:translate_lhs(m.bwd.lhs), s:translate_lhs(m.fwd.lhs)],
        \          s:translate_lhs(a:lhs)) >= 0
        \&& index([mode, ' '], m.bwd.mode) >= 0
        "                      └────────┤
        "                               └ mode of the motion:
        "                                 originally obtained with `maparg()`
        "
        " Why this last condition? {{{
        "
        " We only  pass a lhs  to this function. So, when  it tries to  find the
        " relevant info in  the database, it doesn't care about  the mode of the
        " motion. It stops searching as soon as it finds one which has the right
        " lhs.  It's wrong; it should also care about the mode.
        "
        " Without this condition, here's what could happen:
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
        " Break it down please:{{{
        "
        "     mode:
        "         current mode
        "
        "     index([…, ' '], m.bwd.mode) >= 0
        "
        "         check whether  the mode  of the motion  found in  the database
        "         matches the current one, or a single space.
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

fu! s:invalid_axis_or_direction(axis, direction) abort "{{{2
    let is_valid_axis = has_key(s:last_motions, a:axis) >= 0
    let is_valid_direction = index(['bwd', 'fwd'], a:direction) >= 0
    return !is_valid_axis || !is_valid_direction
endfu

fu! lg#motion#repeatable#make#is_repeating(axis) abort "{{{2
    return get(s:is_repeating_motion, a:axis, 0)
endfu

fu! s:make_keys_feedable(seq) abort "{{{2
    let m = escape(a:seq, '"\')
    let special_chars = [
    \                    '<BS>',
    \                    '<Bar>',
    \                    '<Bslash>',
    \                    '<C-',
    \                    '<CR>',
    \                    '<Del>',
    \                    '<Down>',
    \                    '<End>',
    \                    '<Esc>',
    \                    '<F',
    \                    '<Home>',
    \                    '<Left>',
    \                    '<M-',
    \                    '<PageDown>',
    \                    '<PageUp>',
    \                    '<Plug>',
    \                    '<Right>',
    \                    '<S-',
    \                    '<Space>',
    \                    '<Tab>',
    \                    '<Up>',
    \                    '<lt>',
    \                   ]
    for s in special_chars
        let m = substitute(m, '\c\('.s.'\)', '\\\1', 'g')
    endfor

    " Don't use `string()`.
    " We need double quotes to translate special characters.
    sil exe 'return "'.m.'"'
endfu

fu! s:translate_lhs(lhs) abort "{{{2
    return eval('"'.escape(substitute(a:lhs, '<\ze[^>]\+>', '\\<', 'g'), '"').'"')
endfu

fu! s:unshadow(m, mode) abort "{{{2
    let map_save = lg#map#save(a:mode, 1, [a:m.bwd, a:m.fwd])
    exe 'sil! '.a:mode.'unmap <buffer> '.a:m.bwd
    exe 'sil! '.a:mode.'unmap <buffer> '.a:m.fwd
    return map_save
endfu
