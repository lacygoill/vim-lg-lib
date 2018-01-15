" Why a guard?{{{
"
" We need to assign values to some variables, for the functions to work.
"
" Big deal (/s) … So what?
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

if exists('g:autoloaded_lg#motions#main')
    finish
endif
let g:autoloaded_lg#motions#main = 1

" FIXME:
"     ListRepeatableMotions -scope global -vv -axis 1
"
" Prints:
"
"     Motions on axis:  2
"       ∅
"
"     Motions on axis:  3
"       ∅
"
"     Motions on axis:  4
"       ∅
"
" While it should not print anything.


" TODO:
" create a function in the plugin which makes motions repeatable
" to manually set the last motion on a given axis
"
" Not sure this is a good idea.
" It's a bit unexpected to see that `;` has changed its behavior when
" we execute some commands but not others.
"
" And if that makes us lose a previous motion…
"
" Don't know.

" TODO:
" Remove `g:motion_to_repeat` everywhere.

" TODO:
" We invoke `maparg()` too many times.
" To optimize. (What about `type()`?)
"
" It's called in:
"
"     make_repeatable()      (unavoidable, because initial)
"     s:populate()           (unavoidable, because we need maparg but for another direction)
"     s:get_motion_info()    (avoidable?)
"
" `s:get_motion_info()` is called in:
"
"         move_again()
"         s:move()
"         s:get_direction()
"         s:update_last_motion()

" TODO:
" Split the code in several files if needed.
" Also, make the signature of the main function similar to `submode#map()`;
" which means we shouldn't use a dictionary of arguments, just plain arguments.
" This would allow us to eliminate `make_repeatable()`.
"
" Also, I'm not satisfied with the current architecture of files for this plugin.
" Also, maybe we should move it back to its own plugin.

fu! s:init() abort "{{{1
    let s:repeatable_motions = []
    let s:DEFAULT_MAPARG     = {'buffer': 0, 'expr': 0, 'mode': ' ', 'noremap': 1, 'nowait': 0, 'silent': 0}
    "                                                       Why? ┘{{{
    "
    " This variable will be used to populate information about a default motion,
    " for which `maparg()` doesn't output anything. We need to choose a character
    " standing for the default mode we want. As a default mode, I want `nvo`.
    " For `maparg()`, `nvo` is represented with:
    "
    "     • an empty string in its input
    "     • a single space in its output
    "
    " We need to be consistent with the output of `maparg()`. So, we choose
    " an empty space.
"}}}
    let s:AXES = {
    \              '1': 1,
    \              '2': 2,
    \              '3': 3,
    \              '4': 4,
    \            }

    let s:N_AXES = len(s:AXES)

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

    for i in range(1, s:N_AXES)
        " Used to mark the last motion in the output of `:ListRepeatableMotions`.
        let s:last_motion_on_axis_{i} = ''
        " See :h repeatable-motions-relative-direction, and `tfs_workaround()`
        " for a use of this variable.
        let s:repeating_motion_on_axis_{i} = 0
    endfor
endfu
call s:init()

fu! s:customize_preview_window() abort "{{{1
    if &l:pvw
        call matchadd('Title', '^Motions on axis:  \d\+$')
        call matchadd('SpecialKey', '^global\|local$')
        " Why?{{{
        "
        " If we  press `gf` on a  filepath, it will replace  the preview buffer.
        " After that, we won't be able  to load the preview buffer back, because
        " we've set 'bt=nofile'.
        "
        " To avoid  this accident, we  remap `gf` so  that it splits  the window
        " before reading another file.
        "}}}
        nno  <buffer><nowait><silent>  gf  <c-w>Fzv
        "                                       │└┤
        "                                       │ └ open possible folds
        "                                       └── go to line number after colon
    endif
endfu

fu! s:get_direction(lhs) abort "{{{1
    let motion = s:get_motion_info(a:lhs)
    if type(motion) != type({})
        return ''
    endif
    let is_fwd = s:translate_lhs(a:lhs) ==# s:translate_lhs(motion.fwd.lhs)
    return is_fwd ? 'fwd' : 'bwd'
endfu

fu! s:get_mapcmd(mode, maparg) abort "{{{1
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

fu! s:get_current_mode() abort "{{{1
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
fu! s:get_motion_info(lhs) abort "{{{1
    " return any motion which:
    "
    "     • is registered as repeatable  (i.e. is present inside [s:|b:]repeatable_motions)
    "     • contains a lhs (forward or backward) equal to the one received by the function

    let mode = s:get_current_mode()
    let motions = get(maparg(a:lhs, mode, 0, 1), 'buffer', 0)
    \?                get(b:, 'repeatable_motions', [])
    \:                s:repeatable_motions

    for m in motions
        if  index([s:translate_lhs(m.bwd.lhs), s:translate_lhs(m.fwd.lhs)],
        \          s:translate_lhs(a:lhs)) >= 0
        \&& index([mode, ' '], m.bwd.mode) >= 0
        "                      └────────┤
        "                               └ this flag was originally obtained with `maparg()`
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
        " For `maparg()`,  a single space matches  all the modes in  which we're
        " interested: normal, visual, operator-pending.  So, it should always be
        " right for the motion we're looking for.
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

fu! s:get_line_in_listing(m,n,desired_mode) abort "{{{1
    let motion_mode = a:m.bwd.mode
    if !empty(a:desired_mode) && motion_mode !=# a:desired_mode
        return ''
    endif
    let line  = a:m.bwd.mode.'  '
    let line .= a:m.bwd.lhs
    let line .= ' : '.a:m.fwd.lhs
    " make last motion  used on this axis visible, by  prefixing it with
    " an asterisk
    if index([a:m.bwd.lhs, a:m.fwd.lhs], s:last_motion_on_axis_{a:n}) >= 0
        let line = '* '.line
    endif
    return line
endfu

fu! s:install_wrapper(mode, m, maparg) abort "{{{1
    let mapcmd = s:get_mapcmd(a:mode, a:maparg)
    exe mapcmd.'  '.a:m.bwd.'  <sid>move('.string(a:m.bwd).', '.get(a:maparg, 'buffer', 0).', 1)'
    exe mapcmd.'  '.a:m.fwd.'  <sid>move('.string(a:m.fwd).', '.get(a:maparg, 'buffer', 0).', 1)'
endfu

fu! s:invalid_axis_or_direction(axis, direction) abort "{{{1
    let is_valid_axis = index(values(s:AXES), a:axis) >= 0
    let is_valid_direction = index(['bwd', 'fwd'], a:direction) >= 0
    return !is_valid_axis || !is_valid_direction
endfu

fu! s:is_inconsistent(motion) abort "{{{1
    if   a:motion.bwd.buffer && !a:motion.fwd.buffer
    \|| !a:motion.bwd.buffer &&  a:motion.fwd.buffer
        try
            throw printf('%s and %s must be buffer or global mappings',
            \             a:motion.bwd.lhs,
            \             a:motion.fwd.lhs)
        catch
            return lg#catch_error()
        finally
            return 1
        endtry
    endif
    return 0
endfu

fu! lg#motion#main#list_motions(...) abort "{{{1
    let cmd_args = split(a:1)
    let opt = {
    \           'axis':     matchstr(a:1, '-axis\s\+\zs\d\+'),
    \           'mode':     matchstr(a:1, '\v-mode\s+\zs%(\w|-)+'),
    \           'scope':    matchstr(a:1, '\v-scope\s+\zs\w+'),
    \           'verbose1': index(cmd_args, '-v') >= 0,
    \           'verbose2': index(cmd_args, '-vv') >= 0,
    \         }

    let opt.mode = substitute(opt.mode, 'nvo', ' ', '')

    " initialize each listing scoped to a given axis
    for i in range(1, s:N_AXES)
        let s:listing_for_axis_{i} = {'global': [], 'local': []}
    endfor
    call s:populate_listings_for_all_axes(opt)
    let total_listing = s:merge_listings()

    call lg#log#lines({'excmd': 'ListRepeatableMotions', 'lines': total_listing})
    call s:customize_preview_window()
endfu

fu! lg#motion#main#list_complete(arglead, cmdline, _p) abort "{{{1
    let opt = [
    \           '-axis ',
    \           '-mode',
    \           '-scope ',
    \           '-v ',
    \           '-vv ',
    \         ]

    if  a:arglead[0] ==# '-'
    \|| empty(a:arglead)
    \&& a:cmdline !~# '-\%(axis\|scope\)\s\+$'
    \&& a:cmdline !~# '-mode\s\+\w*$'
        " Why not filtering the options?{{{
        "
        " We don't need to, because the command invoking this completion function is
        " defined with the attribute `-complete=custom`, not `-complete=customlist`,
        " which means Vim performs a basic filtering automatically.
        " }}}
        return join(opt, "\n")

    elseif a:cmdline =~# '-axis\s\+$'
        return join(keys(s:AXES), "\n")

    elseif a:cmdline =~# '-mode \w*$'
        let modes = [
        \             'normal',
        \             'visual',
        \             'operator-pending',
        \           ]
        return join(modes, "\n")

    elseif a:cmdline =~# '-scope\s\+\w*$'
        return "local\nglobal"
    endif

    return ''
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
    \                     '<Plug>',
    \                   ]
    for s in special_chars
        let m = substitute(m, '\c\('.s.'\)', '\\\1', 'g')
    endfor

    " Don't use `string()`.
    " We need double quotes to translate special characters.
    sil exe 'return "'.m.'"'
endfu

fu! lg#motion#main#make_repeatable(what) abort "{{{1
    " can make several motions repeatable

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
        if !is_local && execute(mode.'map <buffer> '.m.bwd) !~# '^\n\nNo mapping found$'
            " Why?{{{
            "
            " If the  motion is global, it  could be shadowed by  a buffer-local
            " mapping  using the  same lhs. We  handle this  particular case  by
            " temporarily removing the latter.
            "}}}
            let map_save = s:unshadow(mode, m)
            call s:make_repeatable(mode, is_local, m, from)
            call lg#map#restore(map_save)
        else
            call s:make_repeatable(mode, is_local, m, from)
        endif
    endfor
endfu

fu! s:make_repeatable(mode, is_local, m, from) abort "{{{1
    " can make only ONE motion repeatable

    let bwd    = a:m.bwd
    let fwd    = a:m.fwd
    let axis   = a:m.axis
    let maparg = maparg(bwd, a:mode, 0, 1)

    if a:is_local && !get(maparg, 'buffer', 0)
        return
    endif

    " Purpose:{{{
    "
    "     1. Install wrapper mappings around a pair of motion mappings.
    "        The wrappers will be used to save the last motion.
    "
    "     2. Add to the list `[s:|b:]repeatable_motions` a dictionary
    "        containing all the information relative to this original pair of
    "        motion mappings. This list is used as a database by the wrappers
    "        to know what the motions are mapped to, and which keys to type in
    "        the typeahead buffer.
    "
    "        This db is also used by :ListRepeatableMotions, to get info
    "        about all motions currently repeatable.
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

    let motion = { 'axis': axis,
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
    call s:populate(motion, a:mode, bwd, 0, maparg)
    " `motion` value is now sth like:{{{
    "
    " { 'axis' : 1,
    "   'bwd'    : {'expr': 0, 'noremap': 1, 'lhs': '…', 'mode': ' ', … }}
    "                                                             │
    "                                                             └ nvo
    "}}}
    call s:populate(motion, a:mode, fwd, 1)
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
    "         call s:make_repeatable({'mode': '',
    "         \                          'buffer': 0,
    "         \                          'motions': {'bwd': '<left>', 'fwd': '<right>', 'axis': 1})
    " TODO:
    " Are you sure this explanation is still valid?
    "
    " Update:
    " Open dirvish right after opening a Vim session (with no files).
    " You'll see the plugin complain because of T (global) + t (local).
    " How can that happen?
    " Those are 2 different motions. Why does the plugin mixes them?
    "
    " Update:
    " Here's what I think happen:
    "
    "     1. you start Vim, and immediately open dirvish
    "
    "     2. the dirvish ftplugin installs a buffer local `t` mapping
    "
    "     3. the timer sources ~/.vim/autoload/slow_mappings/repeatable_motions.vim
    "        which installs the global motion `Tt`
    "        but the previous buffer-local mapping probably interferes
    "
    "        Because of this, the `[tT]x` motion isn't repeatable.
    "}}}
    if  s:is_inconsistent(motion)
        return
    endif

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
    " We need the update the db of local motions, not restart from scratch.
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

    " TODO:
    " This prevents `b:repeatable_motions` from growing when we reload a buffer.
    " But it feels wrong to wait so late.
    " I would prefer to reset the variable early.
    " Besides, it may write something in the log messages (type coD, then :e).
    if s:motion_already_repeatable(motion, repeatable_motions)
        return
    endif

    call s:install_wrapper(a:mode, a:m, maparg)

    " add the motion in a db, so that we can retrieve info about it later;
    " in particular its rhs
    call add(repeatable_motions, motion)

    if a:is_local
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

fu! s:merge_listings(...) abort "{{{1
    " when the function is called for the 1st time, it's not passed any argument
    if !a:0
        "                    ┌ necessary to force `lg#log#lines()` to add a newline
        "                    │ after the title of the buffer;
        "                    │
        "                    │ otherwise `Motions on axis:  1` would be on the same line as the title
        let total_listing = ['']

        for n in range(1, s:N_AXES)
            let total_listing += s:merge_listings(n, s:listing_for_axis_{n})
            unlet! s:listing_for_axis_{n}
        endfor

        return total_listing
    endif

    " when the function is called afterwards (by itself, i.e. recursively),
    " it's passed 2 arguments:
    "
    "     • the index of an axis
    "     • the listing of the latter
    let n = a:1
    let listing_for_this_axis = a:2

    let lines = []
    if n > 1
        let lines += ['']
    endif
    let lines += ['Motions on axis:  '.n]
    if empty(listing_for_this_axis.global) && empty(listing_for_this_axis.local)
        let lines += ['  ∅']
    else
        for scope in ['global', 'local']
            if !empty(listing_for_this_axis[scope])
                let lines += ['', scope]
                for a_line in listing_for_this_axis[scope]
                    let lines += [a_line]
                endfor
            endif
        endfor
    endif
    return lines
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

fu! s:move(lhs, buffer, update_last_motion, ...) abort "{{{1
    " What is the purpose of this optional argument?{{{
    "
    " When it's passed, it means we don't want the function to translate
    " special keys at the end.
    " If we let the function translate them, it will translate `<plug>`.
    "}}}
    " So… We don't want `<plug>` to be translated?{{{
    "
    " It depends.
    "
    " When `s:move()` is called from a  wrapper, the keys are directly typed. In
    " this case, `<plug>` must be translated.
    "
    " But when `s:move()` is called  from `move_again()`, and the latter can't
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

    " Why?{{{
    "
    " To be efficient. There's no need to always update the last motion.
    "}}}
    " When is it useless to update it?{{{
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
        call s:update_last_motion(a:lhs)
    endif

    let motion = s:get_motion_info(a:lhs)
    if type(motion) != type({})
        return ''
    endif

    let dir_key = s:get_direction(a:lhs)
    if empty(dir_key)
        return ''
    endif

    let is_expr_mapping = motion[dir_key].expr
    if motion[dir_key].rhs =~# '\c<sid>'
        let motion[dir_key].rhs =
        \    substitute(motion[dir_key].rhs, '\c<sid>', '<snr>'.motion[dir_key].sid.'_', 'g')
    endif

    " TODO:
    " Shouldn't we invoke `s:make_keys_feedable()` in BOTH cases?
    " What if there are special keys in the rhs of an expr mapping?
    " Or does `eval()` translate them?
    return is_expr_mapping
    \?         eval(motion[dir_key].rhs)
    \:         a:0 ? motion[dir_key].rhs : s:make_keys_feedable(motion[dir_key].rhs)
endfu

fu! lg#motion#main#move_again(axis, dir) abort "{{{1
    " This function is called by various mappings whose suffix is `,` or `;`.

    " make sure the arguments are valid,
    " and that we've used at least one motion on the axis
    if  s:invalid_axis_or_direction(a:axis, a:dir)
    \|| empty(s:last_motion_on_axis_{a:axis})
        return ''
    endif

    " get last motion on the axis provided
    let motion = s:get_motion_info(s:last_motion_on_axis_{a:axis})

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
    "     tfs_workaround('f')
    "
    " And the code in `tfs_workaround()` IS influenced by
    " `s:repeating_motion_on_axis_1`.
    "}}}
    let s:repeating_motion_on_axis_{a:axis} = a:dir ==# 'fwd' ? 1 : -1

    let is_silent = motion[a:dir].silent
    let seq = call('s:move',   [motion[a:dir].lhs, motion[a:dir].buffer, 0]
    \                        + (is_silent ? [1] : []))
    "                                        │
    "                                        └ don't translate special keys;
    "                                        we're going to install a temporary mapping
    "                                        (because the motion must be silent), so `<plug>`
    "                                        must NOT be translated

    " TODO: Why do we reset all these variables?
    " Update:
    " I think it's for a custom function which we could define to implement
    " a special motion like `fFtT`. Similar to `tfs_workaround()`.
    " `fFtT` are special because the lhs, which is saved for repetition, doesn't
    " contain the necessary character which must be passed to the command.
    "
    " Note that `fFtT` are specific to the axis 1, but we could want to define
    " special motions on other axes. That's why, I think, we need to reset
    " ALL variables.
    for i in range(1, s:N_AXES)
        let s:repeating_motion_on_axis_{i} = 0
    endfor

    " if we're using  `]q` &friends (to move  into a list of files),  we need to
    " redraw  all statuslines,  so  that the  position in  the  list is  updated
    " immediately
    if a:axis == 2
        call timer_start(0, {-> execute('redraws!')})
    endif

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
    " Before returning, we must make sure to properly reset `s:repeating_motion_on_axis_…`
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

fu! s:populate(motion, mode, lhs, is_fwd, ...) abort "{{{1
    let maparg = a:0 ? a:1 : maparg(a:lhs, a:mode, 0, 1)
    let dir = a:is_fwd ? 'fwd' : 'bwd'

    " make a custom mapping repeatable
    if !empty(maparg)
        let a:motion[dir] = maparg
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

fu! s:populate_listings_for_all_axes(opt) abort "{{{1
    let lists = a:opt.scope ==# 'local'
    \?              [get(b:, 'repeatable_motions', [])]
    \:          a:opt.scope ==# 'global'
    \?              [s:repeatable_motions]
    \:              [get(b:, 'repeatable_motions', []), s:repeatable_motions]

    for a_list in lists
        let scope = a_list is# s:repeatable_motions ? 'global' : 'local'
        for m in a_list
            let n = m.axis
            if !empty(a:opt.axis) && n != a:opt.axis
                continue
            endif
            let line = s:get_line_in_listing(m,n,a:opt.mode)
            if empty(line)
                continue
            endif
            let line .= a:opt.verbose1
            \?              '    '.m['original mapping']
            \:              ''

            let listing = s:listing_for_axis_{n}[scope]
            " populate `motions_on_axis_123`
            call add(listing, '  '.line)
            if a:opt.verbose2
                call extend(listing,
                \                    (!empty(m['original mapping']) ? ['       '.m['original mapping']] : [])
                \                   +['       Made repeatable from '.m['made repeatable from']]
                \                   +[''])
            endif
        endfor
    endfor
endfu

fu! lg#motion#main#tfs_workaround(cmd) abort "{{{1
    " TODO:{{{
    " We don't need to call this function to make `)` repeatable,
    " so why do we need to call it to make `fx` repeatable?
    "
    " What is special about making `fx` repeatable, compared to `)`?
    "
    " Update:
    " `move_again()` → `s:move()` → `tfs_workaround()`
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
"}}}

    " Why not `call feedkeys('zv', 'int')`?{{{
    "
    " It  would interfere  with  `vim-sneak`,  when the  latter  asks for  which
    " character we want to move on. `zv` would be interpreted like this:
    "
    "     zv
    "     ││
    "     │└ enter visual mode
    "     └ move cursor to next/previous `z` character
    "}}}
    " How is this autocmd better?{{{
    "
    " `feedkeys('zv', 'int')` would IMMEDIATELY press `zv` (✘).
    " The autocmd also presses `zv`, but only after a motion has occurred (✔).
    "}}}
    augroup sneak_open_folds
        au!
        au CursorMoved * exe 'norm! zv'
        \|               exe 'au! sneak_open_folds '
        \|               aug! sneak_open_folds
    augroup END

    " What's the purpose of this `if` conditional?{{{
    "
    " This function can be called:
    "
    "     •   directly from a  [ftFT]  mapping
    "     • indirectly from a  [;,]    mapping
    "       │
    "       └ move_again()  →  s:move()  →  tfs_workaround()
    "
    " It needs to distinguish from where it was called.
    " Because in  the first  case, it  needs to  ask the  user for  a character,
    " before returning the  keys to press. In the other, it  doesn't need to ask
    " anything.
    "}}}
    if s:repeating_motion_on_axis_1
    "                             │
    "                             └ `[tfTF]x` motions are specific to the axis 1,
    "                                so there's no need to check `s:repeating_motion_on_axis_2,3,…`

        let move_fwd = a:cmd =~# '\C[tfs]'
        "              │{{{
        "              └ TODO: What is this?
        "
        " When we press `;` after `fx`, how is `a:cmd` obtained?
        "
        "   Update: It's `f`.
        "   Here's what happens approximately:
        "
        "   ;  →  move_again(1,'fwd'))
        "
        "                 s:get_motion_info(s:last_motion_on_axis_1)  saved in `motion`
        "                                   │
        "                                   └ 'f'
        "
        "         s:move(motion.fwd.lhs, 0, 0)
        "                │
        "                └ 'f'
        "
        "                 s:get_motion_info(a:lhs)  saved in `motion`
        "                                   │
        "                                   └ 'f'
        "
        "                 s:get_direction(a:lhs)  saved in `dir_key`
        "                 │
        "                 └ 'fwd'
        "
        "         eval(motion[dir_key].rhs)
        "              └─────────────────┤
        "                                └ tfs_workaround('f')
        "                                                  │
        "                                                  └ !!! a:cmd !!!
        "
        "          Consequence of all of this:
        "          our plugin normalizes the direction of the motions `,` and `;`
        "          i.e. `;` always moves the cursor forward no matter whether
        "          we previously used f or F or t or T
        "          In fact, it seems the normalization applies also to non-f motions!
        "          Document this automatic normalization somewhere.
        "}}}
        call feedkeys(move_fwd ? "\<plug>Sneak_;" : "\<plug>Sneak_,", 'i')
    else
        call feedkeys("\<plug>Sneak_".a:cmd, 'i')
    endif
    return ''
endfu

fu! s:translate_lhs(lhs) abort "{{{1
    return eval('"'.escape(substitute(a:lhs, '<\ze[^>]\+>', '\\<', 'g'), '"').'"')
endfu

fu! s:unshadow(mode, m) abort "{{{1
    let map_save = lg#map#save(a:mode, 1, [a:m.bwd, a:m.fwd])
    exe a:mode.'unmap <buffer> '.a:m.bwd
    exe a:mode.'unmap <buffer> '.a:m.fwd
    return map_save
endfu

fu! s:update_last_motion(lhs) abort "{{{1
    let motion = s:get_motion_info(a:lhs)
    if type(motion) != type({})
        return
    endif
    let n = motion.axis
    " TODO:
    " Should we translate `a:lhs`?
    " I think yes. Why?
    " Because this function is called at the beginning of `s:move()`.
    " The  latter passes  to it  a keysequence,  which originally  comes from  a
    " mapping:  Vim automatically translates it.
    "
    "     mapping → s:move(lhs, …) → s:update_last_motion(lhs)
    "     │                │                              │
    "     │                │                              └ same result
    "     │                │
    "     │                └ result of the previous translation
    "     │
    "     └ automatically translates special keys
    let s:last_motion_on_axis_{n} = s:translate_lhs(a:lhs)
endfu

fu! s:update_undo_ftplugin() abort "{{{1
    if stridx(get(b:, 'undo_ftplugin', ''), 'unlet! b:repeatable_motions') == -1
        let b:undo_ftplugin =          get(b:, 'undo_ftplugin', '')
        \                     . (empty(get(b:, 'undo_ftplugin', '')) ? '' : '|')
        \                     . 'unlet! b:repeatable_motions'
    endif
endfu

