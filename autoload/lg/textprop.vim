fu lg#textprop#ansi() abort "{{{1
    if !search('\e', 'cn') | return | endif
    let view = winsaveview()

    hi ansiBold term=bold cterm=bold gui=bold
    hi ansiBoldUnderlined term=bold,underline cterm=bold,underline gui=bold,underline

    " Why do you use text properties and not regex-based syntax highlighting?{{{
    "
    " Using text properties allows us to remove the ansi codes.
    " This way, if we yank some line, we don't copy them.
    "}}}
    "   How would I get the same highlighting with syntax rules?{{{
    "
    "     syn region ansiBold matchgroup=Normal start=/\e\[1m/ end=/\e\[22m/ concealends oneline
    "     syn region ansiBoldUnderlined matchgroup=Normal start=/\e\[4m\e\[1m/ end=/\e\[22m\e\[24m/ concealends oneline
    "     setl cole=3 cocu=nc
    "
    " Do not remove `oneline`.
    "
    " It would sometimes highlight text while it shouldn't.
    " E.g.:
    "
    "     $ env | vipe
    "
    " In this example, the issue comes from some environment variables which
    " contain escape sequences (`FINGERS_...`).
    "
    " Besides, I think  that most of the time, programs  which output escape
    " sequences do it only for a short text on a single line...
    "}}}
    if !has('nvim')
        call prop_type_add('ansibold', {'highlight': 'ansiBold', 'bufnr': bufnr('%')})
        call prop_type_add('ansiboldunderlined', {'highlight': 'ansiBoldUnderlined', 'bufnr': bufnr('%')})
        call cursor(1, 1)
        while search('\e\[1m', 'W')
            call prop_add(line('.'), col('.'), {
                \ 'length': searchpos('\e\[22m\zs', 'cn')[1] - col('.'),
                \ 'type': 'ansibold',
                \ })
        endwhile
        call cursor(1, 1)
        while search('\e\[4m\e\[1m', 'W')
            call prop_add(line('.'), col('.'), {
                \ 'length': searchpos('\e\[22m\e\[24m\zs', 'cn')[1] - col('.'),
                \ 'type': 'ansiboldunderlined'
                \ })
        endwhile
    else
        let id = nvim_create_namespace('ansi')
        call cursor(1, 1)
        while search('\e\[1m', 'W')
            call nvim_buf_add_highlight(0, id, 'ansiBold',
                \ line('.')-1, col('.'), searchpos('\e\[22m\zs', 'cn')[1]-1)
        endwhile
        call cursor(1, 1)
        while search('\e\[4m\e\[1m', 'W')
            call nvim_buf_add_highlight(0, id, 'ansiBoldUnderlined',
                \ line('.')-1, col('.'), searchpos('\e\[22m\e\[24m\zs', 'cn')[1]-1)
        endwhile
    endif

    sil keepj keepp lockm %s/\e\[1m\|\e\[22m\|\e\[4m\e\[1m\|\e\[24m//ge
    setl nomod
    call winrestview(view)
endfu

