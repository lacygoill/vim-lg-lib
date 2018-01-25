" TODO:
" Add `C-n` `C-p` mappings to move between the axes.
" And `C-j` `C-k` to move between scopes?
"
" NOTE:
" Using C-n and C-p to move between tabpages is a bad idea.
" Every time we end  up in a special buffer where  local mappings are installed,
" and which use these keys, we can't move to another tabpage.
"
" We could use `gh` and `gl` as a replacement. But they use 2 keys.
" We could create a submode, but we would need to quit it every time.
" Annoying.
" Maybe if we tweaked `vim-submode` to automatically quit the submode
" via a timer after a short time. Long enough to let us smash `h` and `l`
" while in the submode, but short enough so that we don't have to quit
" the submode.

" TODO:
" Show the total command which has been used to produce the output.
" You'll have to tweak `lg#log#output()`.

" TODO:
" Show the name of the axis even when using `-axis`.
" Are there other (combination of) arguments for which there's not enough info?

if exists('g:autoloaded_lg#motion#repeatable#listing')
    finish
endif
let g:autoloaded_lg#motion#repeatable#listing = 1

fu! s:init() abort "{{{1
    let s:repeatable_motions = lg#motion#repeatable#make#share_env()
    let s:axes = uniq(sort(map(deepcopy(s:repeatable_motions), {i,v -> v.axis})))
    let s:mode2letter = {'normal': 'n', 'visual': 'x', 'operator-pending': 'no', 'nvo': ' '}
endfu

" Interface {{{1
fu! lg#motion#repeatable#listing#complete(arglead, cmdline, _p) abort "{{{2
    " We  re-init every  time we  complete `:ListRepeatableMotions`,  because we
    " could make some motions repeatable during  runtime, and use a new axis. In
    " that case, we want to see the latter in the suggestions after `-axis`.
    call s:init()

    " We always assume that the cursor is at the very end of the command line.
    " That's why we never use `a:_p`.

    if a:cmdline =~# '-axis\s\+\S*$'
        return join(s:axes, "\n")

    elseif a:cmdline =~# '-mode\s\+\w*$'
        let modes = [
        \             'normal',
        \             'visual',
        \             'operator-pending',
        \             'nvo',
        \           ]
        return join(modes, "\n")

    elseif a:cmdline =~# '-scope\s\+\w*$'
        return "local\nglobal"

    elseif empty(a:arglead) || a:arglead[0] ==# '-'
        " Why not filtering the options?{{{
        "
        " We don't need to, because the command invoking this completion function is
        " defined with the attribute `-complete=custom`, not `-complete=customlist`,
        " which means Vim performs a basic filtering automatically.
        " }}}
        let opt = [
        \           '-axis ',
        \           '-mode ',
        \           '-scope ',
        \           '-v ',
        \           '-vv ',
        \         ]
        return join(opt, "\n")
    endif

    return ''
endfu

fu! lg#motion#repeatable#listing#main(...) abort "{{{2
    " We re-init every time we execute `:ListRepeatableMotions`,
    " because we could make some motions repeatable during runtime.
    call s:init()

    let cmd_args = split(a:1)
    let opt = {
    \           'axis':     matchstr(a:1, '\v-axis\s+\zs\S+'),
    \           'mode':     matchstr(a:1, '\v-mode\s+\zs[-a-z]+'),
    \           'scope':    matchstr(a:1, '\v-scope\s+\zs\w+'),
    \           'verbose1': index(cmd_args, '-v') >= 0,
    \           'verbose2': index(cmd_args, '-vv') >= 0,
    \         }

    let opt.mode = has_key(s:mode2letter, opt.mode) ? s:mode2letter[opt.mode] : ' '

    let axes_asked = !empty(opt.axis) ? [opt.axis] : s:axes

    call s:init_listings_for_all_axes(axes_asked)

    call s:populate_listings(opt)

    let total_listing = s:merge_listings(axes_asked)

    " show the result
    call lg#log#output({'lines': total_listing})
    call s:customize_preview_window()
    sil! 1/^Motions/?\n\n?d_
    sil keepj keepp %s/\v\n{3,}/\r\r/e
    sil! 1/^Motions/
endfu

" Core {{{1
fu! s:add_text_to_write(opt, m, scope) abort "{{{2
    let line = printf('  %s  %s : %s',
    \                 a:m.bwd.mode, a:m.bwd.untranslated_lhs, a:m.fwd.untranslated_lhs)

    let line .= a:opt.verbose1
    \?              '    '.a:m['original mapping']
    \:              ''

    let listing_for_axis_and_scope = s:listing_per_axis[a:m.axis][a:scope]
    " Why `add()`?{{{
    "
    " Why not:
    "
    "     let listing_for_axis_and_scope .= line
    "
    " For the same reason explained in the next comment.
    " We're going to write this text via `writefile()`.
    " The latter expects a list of strings. Not a string.
    "}}}
    call add(listing_for_axis_and_scope, line)

    if a:opt.verbose2
        " Why `extend()`?{{{
        "
        " Why didn't you wrote earlier:
        "
        "     let line .= "\n"
        "     \           .'       '.a:m['original mapping']."\n"
        "     \           .'       Made repeatable from '.a:m['made repeatable from']
        "     \           ."\n"
        "
        " Because eventually, we're going to write the text via `lg#log#output()`
        " which itself invokes `writefile()`. And the latter writes "\n" as a NUL.
        " The only way to make `writefile()` write a newline is to split the lines
        " into several list items.
        "}}}
        call extend(listing_for_axis_and_scope,
        \                ['       '.a:m['original mapping']]
        \               +['       Made repeatable from '.a:m['made repeatable from']]
        \               +[''])
    endif
endfu

fu! s:merge_listings(axes, ...) abort "{{{2
    " when the function is called for the 1st time, it's not passed any optional argument
    if !a:0
        let total_listing = []

        for axis in a:axes
            let total_listing += s:merge_listings(a:axes, axis, s:listing_per_axis[axis])
        endfor
        " the listings have all been merged,
        " they are not needed anymore, so we can safely remove them
        unlet! s:listing_per_axis

        return total_listing
    endif

    " when the function is called afterwards (by itself, i.e. recursively),
    " it's passed 2 additional arguments:
    "
    "     • the name of an axis
    "     • the listing of the latter
    let axis = a:1
    let listing_for_this_axis = a:2

    let lines = ['', 'Motions repeated with:  '.substitute(axis, '_', ' : ', '')]
    if empty(listing_for_this_axis.global) && empty(listing_for_this_axis.local)
        return []
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

fu! s:populate_listings(opt) abort "{{{2
    let lists = a:opt.scope ==# 'local'
    \?              [get(b:, 'repeatable_motions', [])]
    \:          a:opt.scope ==# 'global'
    \?              [s:repeatable_motions]
    \:              [get(b:, 'repeatable_motions', []), s:repeatable_motions]

    for a_list in lists
        let scope = a_list is# s:repeatable_motions ? 'global' : 'local'
        for m in a_list
            if  !empty(a:opt.axis) && a:opt.axis !=# m.axis
            \|| !empty(a:opt.mode) && a:opt.mode !=# m.bwd.mode
                continue
            endif

            call s:add_text_to_write(a:opt, m, scope)
        endfor
    endfor
endfu

" Misc. {{{1
fu! s:customize_preview_window() abort "{{{2
    if &l:pvw
        call matchadd('Title', '^Motions repeated with:')
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

fu! s:init_listings_for_all_axes(axes) abort "{{{2
    let s:listing_per_axis = {}
    for axis in a:axes
        let s:listing_per_axis[axis] = {'global': [], 'local': []}
    endfor
endfu
