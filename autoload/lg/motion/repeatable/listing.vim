if exists('g:autoloaded_lg#motion#repeatable#listing')
    finish
endif
let g:autoloaded_lg#motion#repeatable#listing = 1

fu! s:init() abort "{{{1
    let s:REPEATABLE_MOTIONS = lg#motion#repeatable#make#share_env()
    let s:AXES = uniq(sort(map(deepcopy(s:REPEATABLE_MOTIONS), {i,v -> v.axis})))
    let s:MODE2LETTER = {'normal': 'n', 'visual': 'x', 'operator-pending': 'no', 'nvo': ' '}
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
        return join(s:AXES, "\n")

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

    elseif empty(a:arglead) || a:arglead[0] is# '-'
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

    " get the asked options
    let cmd_args = split(a:1)
    let opt = {
    \           'axis':     matchstr(a:1, '\v-axis\s+\zs\S+'),
    \           'mode':     matchstr(a:1, '\v-mode\s+\zs[-a-z]+'),
    \           'scope':    matchstr(a:1, '\v-scope\s+\zs\w+'),
    \           'verbose1': index(cmd_args, '-v') >= 0,
    \           'verbose2': index(cmd_args, '-vv') >= 0,
    \         }
    let opt.mode = has_key(s:MODE2LETTER, opt.mode) ? s:MODE2LETTER[opt.mode] : ''
    let axes_asked = !empty(opt.axis) ? [opt.axis] : s:AXES

    " get the text to display
    call s:init_listings_for_all_axes(axes_asked)
    call s:populate_listings(opt)
    let total_listing = s:merge_listings(axes_asked)

    " display it
    let excmd = 'ListRepeatableMotions '.a:1
    call debug#log#output({'excmd': excmd, 'lines': total_listing})
    call s:customize_preview_window()
endfu

" Core {{{1
fu! s:add_text_to_write(opt, m, scope) abort "{{{2
    let text = printf('  %s  %s | %s',
    \                 a:m.bwd.mode, a:m.bwd.untranslated_lhs, a:m.fwd.untranslated_lhs)
    let text .= a:opt.verbose1
            \ ?     '    '.a:m['original mapping']
            \ :     ''

    let lines = [text]
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
        " Because eventually, we're going to write the text via `debug#log#output()`
        " which itself invokes `writefile()`. And the latter writes "\n" as a NUL.
        " The only way to make `writefile()` write a newline is to split the lines
        " into several list items.
        "}}}
        call extend(lines,
        \                ['       '.a:m['original mapping']]
        \               +['       Made repeatable from '.a:m['made repeatable from']]
        \               +[''])
    endif

    call extend(s:listing_per_axis[a:m.axis][a:scope], lines)
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

    let lines = ['', 'Motions repeated with:  '.substitute(axis, '_', ' | ', '')]
    if empty(listing_for_this_axis.global) && empty(listing_for_this_axis.local)
        return []
    else
        for scope in ['global', 'local']
            if !empty(listing_for_this_axis[scope])
                let lines += ['', scope, '']
                for a_line in listing_for_this_axis[scope]
                    let lines += [a_line]
                endfor
            endif
        endfor
    endif
    return lines
endfu

fu! s:populate_listings(opt) abort "{{{2
    let lists = a:opt.scope is# 'local'
            \ ?     [get(b:, 'repeatable_motions', [])]
            \ : a:opt.scope is# 'global'
            \ ?     [s:REPEATABLE_MOTIONS]
            \ :     [get(b:, 'repeatable_motions', []), s:REPEATABLE_MOTIONS]

    for a_list in lists
        let scope = a_list is# s:REPEATABLE_MOTIONS ? 'global' : 'local'
        for m in a_list
            if  !empty(a:opt.axis) && a:opt.axis isnot# m.axis
            \|| !empty(a:opt.mode) && a:opt.mode isnot# m.bwd.mode
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
        call matchadd('SpecialKey', '^\%(global\|local\)$')

        call lg#window#openable_anywhere()

        nno  <buffer><nowait><silent>  }  :<c-u>call search('^\%(Motions\<bar>local\<bar>global\)')<cr>
        nno  <buffer><nowait><silent>  {  :<c-u>call search('^\%(Motions\<bar>local\<bar>global\)', 'b')<cr>
        sil! 1/^Motions/
    endif
endfu

fu! s:init_listings_for_all_axes(axes) abort "{{{2
    let s:listing_per_axis = {}
    for axis in a:axes
        let s:listing_per_axis[axis] = {'global': [], 'local': []}
    endfor
endfu
