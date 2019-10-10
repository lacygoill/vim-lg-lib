if exists('g:autoloaded_lg#motion#repeatable#listing')
    finish
endif
let g:autoloaded_lg#motion#repeatable#listing = 1

" init {{{1

let s:REPEATABLE_MOTIONS = lg#motion#repeatable#make#share_env()
let s:MODE2LETTER = {'normal': 'n', 'visual': 'x', 'operator-pending': 'no', 'nvo': ' '}

" Interface {{{1
fu! lg#motion#repeatable#listing#complete(arglead, cmdline, pos) abort "{{{2
    let word_before_cursor = matchstr(a:cmdline, '.*\s\zs-\S.*\%'.a:pos.'c.')
    if word_before_cursor =~# '-mode\s\+\w*$'
        let modes = [
            \ 'normal',
            \ 'visual',
            \ 'operator-pending',
            \ 'nvo',
            \ ]
        return join(modes, "\n")

    elseif word_before_cursor =~# '-scope\s\+\w*$'
        return "local\nglobal"

    elseif empty(a:arglead) || a:arglead[0] is# '-'
        let opt = [
            \ '-mode ',
            \ '-scope ',
            \ '-v ',
            \ '-vv ',
            \ ]
        return join(opt, "\n")
    endif

    return ''
endfu

fu! lg#motion#repeatable#listing#main(...) abort "{{{2
    " get the asked options
    let cmd_args = split(a:1)
    let opt = {
        \ 'mode':     matchstr(a:1, '\v-mode\s+\zs[-a-z]+'),
        \ 'scope':    matchstr(a:1, '\v-scope\s+\zs\w+'),
        \ 'verbose1': index(cmd_args, '-v') >= 0,
        \ 'verbose2': index(cmd_args, '-vv') >= 0,
        \ }
    let opt.mode = has_key(s:MODE2LETTER, opt.mode) ? s:MODE2LETTER[opt.mode] : ''

    " get the text to display
    let s:listing = {'global': [], 'local': []}
    call s:populate_listing(opt)

    " display it
    let excmd = 'RepeatableMotions '.a:1
    call debug#log#output({'excmd': excmd, 'lines': s:get_lines()})
    call s:customize_preview_window()
endfu
" }}}1
" Core {{{1
fu! s:populate_listing(opt) abort "{{{2
    let lists = a:opt.scope is# 'local'
            \ ?     [get(b:, 'repeatable_motions', [])]
            \ : a:opt.scope is# 'global'
            \ ?     [s:REPEATABLE_MOTIONS]
            \ :     [get(b:, 'repeatable_motions', []), s:REPEATABLE_MOTIONS]

    for a_list in lists
        let scope = a_list is# s:REPEATABLE_MOTIONS ? 'global' : 'local'
        for m in a_list
            if !empty(a:opt.mode) && a:opt.mode isnot# m.bwd.mode
                continue
            endif

            call s:add_text_to_write(a:opt, m, scope)
        endfor
    endfor
endfu

fu! s:add_text_to_write(opt, m, scope) abort "{{{2
    let text = printf('  %s  %s | %s',
    \                 a:m.bwd.mode, a:m.bwd.untranslated_lhs, a:m.fwd.untranslated_lhs)
    let text ..= a:opt.verbose1
            \ ?     '    '.a:m['original mapping']
            \ :     ''

    let lines = [text]
    if a:opt.verbose2
        " Why `extend()`?{{{
        "
        " Why didn't you wrote earlier:
        "
        "     let line ..= "\n"
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

    call extend(s:listing[a:scope], lines)
endfu

fu! s:get_lines() abort "{{{2
    if empty(s:listing.global) && empty(s:listing.local)
        return []
    else
        let lines = []
        for scope in ['global', 'local']
            if !empty(s:listing[scope])
                let lines += ['', scope, '']
                for a_line in s:listing[scope]
                    let lines += [a_line]
                endfor
            endif
        endfor
        return lines
    endif
endfu
" }}}1
" Misc. {{{1
fu! s:customize_preview_window() abort "{{{2
    if &l:pvw
        call matchadd('Title', '^Motions repeated with:')
        call matchadd('SpecialKey', '^\%(global\|local\)$')

        nno <buffer><nowait><silent> ]] :<c-u>call search('^\%(Motions\<bar>local\<bar>global\)')<cr>
        nno <buffer><nowait><silent> [[ :<c-u>call search('^\%(Motions\<bar>local\<bar>global\)', 'b')<cr>
        sil! 1/^Motions/
    endif
endfu

