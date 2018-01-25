if exists('g:autoloaded_lg#motion#repeatable#listing')
    finish
endif
let g:autoloaded_lg#motion#repeatable#listing = 1

fu! s:init() abort "{{{1
    let s:repeatable_motions = lg#motion#repeatable#make#share_env()
    let s:axes = uniq(sort(map(deepcopy(s:repeatable_motions), {i,v -> v.axis})))
endfu
call s:init()

" Interface {{{1
fu! lg#motion#repeatable#listing#complete(arglead, cmdline, _p) abort "{{{2
    " We always assume that the cursor is at the very end of the command line.
    " That's why we never use `a:_p`.

    if a:cmdline =~# '-axis\s\+\S*$'
        return join(s:axes,"\n")

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
    let cmd_args = split(a:1)
    let opt = {
    \           'axis':     substitute(matchstr(a:1, '\v-axis\s+\zs\S+'), '_', ' ', 'g'),
    \           'mode':     matchstr(a:1, '\v-mode\s+\zs%(\w|-)+'),
    \           'scope':    matchstr(a:1, '\v-scope\s+\zs\w+'),
    \           'verbose1': index(cmd_args, '-v') >= 0,
    \           'verbose2': index(cmd_args, '-vv') >= 0,
    \         }

    let opt.mode = substitute(opt.mode, 'nvo', ' ', '')

    " initialize a listing for every given axis
    let s:listing_per_axis = {}
    for axis in s:axes
        let s:listing_per_axis[axis] = {'global': [], 'local': []}
    endfor

    " populate them
    call s:populate_listings_for_all_axes(opt)

    " merge them
    let total_listing = s:merge_listings(opt)

    " show the result
    call lg#log#output({'excmd': 'ListRepeatableMotions', 'lines': total_listing})
    call s:customize_preview_window()
    1/^Motions/?\n\n?d_
    sil keepj keepp %s/\v\n{3,}/\r\r/e
endfu

" Core {{{1
fu! s:merge_listings(opt, ...) abort "{{{2
    " when the function is called for the 1st time, it's not passed any optional argument
    if !a:0
        let total_listing = []

        for axis in s:axes
            let total_listing += s:merge_listings(a:opt, axis, s:listing_per_axis[axis])
            unlet! s:listing_per_axis[axis]
        endfor

        return total_listing
    endif

    " when the function is called afterwards (by itself, i.e. recursively),
    " it's passed 2 additional arguments:
    "
    "     • the name of an axis
    "     • the listing of the latter
    let axis = a:1
    let listing_for_this_axis = a:2

    if !empty(a:opt.axis) && axis !=# a:opt.axis
        return []
    endif

    let lines = ['']
    let lines += ['Motions repeated with:  '.axis]
    if empty(listing_for_this_axis.global) && empty(listing_for_this_axis.local)
        call remove(lines, -1)
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

fu! s:populate_listings_for_all_axes(opt) abort "{{{2
    let lists = a:opt.scope ==# 'local'
    \?              [get(b:, 'repeatable_motions', [])]
    \:          a:opt.scope ==# 'global'
    \?              [s:repeatable_motions]
    \:              [get(b:, 'repeatable_motions', []), s:repeatable_motions]

    for a_list in lists
        let scope = a_list is# s:repeatable_motions ? 'global' : 'local'
        for m in a_list
            if !empty(a:opt.axis) && m.axis !=# a:opt.axis
                continue
            endif
            let line = s:get_line_in_listing(m, a:opt.mode)
            if empty(line)
                continue
            endif
            let line .= a:opt.verbose1
            \?              '    '.m['original mapping']
            \:              ''

            let listing = s:listing_per_axis[m.axis][scope]
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

fu! s:get_line_in_listing(m, desired_mode) abort "{{{2
    let motion_mode = a:m.bwd.mode
    if !empty(a:desired_mode) && motion_mode !=# a:desired_mode
        return ''
    endif
    let line  = a:m.bwd.mode.'  '
    let line .= a:m.bwd.untranslated_lhs
    let line .= ' : '.a:m.fwd.untranslated_lhs
    return line
endfu
