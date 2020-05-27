if exists('g:autoloaded_lg#textprop')
    finish
endif
let g:autoloaded_lg#textprop = 1

" Init {{{1

" Should support commands like `tldr(1)` and `trans(1)`:{{{
"
"     $ tldr tldr | vipe
"     $ trans word tldr | vipe
"}}}
" Why do you set the `gui`/`guifg` attributes?  We can only pipe the output of a shell command to Vim in the terminal...{{{
"
" Yes, but if `'tgc'` is set, (N)Vim uses `guifg` instead of `ctermfg`.
" And Nvim uses `gui` instead of `cterm`.
"}}}

" TODO: Get those sequences programmatically via `tput(1)`.{{{
"
" Issue: I can't find some of them in `$ infocmp -1x`.
"
" I don't know their name:
"
"    - C-o
"    - CSI 22m
"
" I think they are hard-coded in the program which produce them.
" For example,  if you grep  the pattern `\[22`  in the codebase  of `trans(1)`,
" you'll find this:
"
"     AnsiCode["no bold"] = "\33[22m" # SGR code 21 (bold off) not widely supported
"}}}
" CSI 1m = bold (bold)
" CSI 3m = italicized (sitm)
" CSI 4m = underlined (smul)
" CSI 22m = normal (???)
" CSI 23m = not italicized (ritm)
" CSI 24m = not underlined (rmul)
" CSI 32m = green (setaf 2)
" C-o     = ??? (???)

const s:ATTR = {
    \ 'trans_bold': {
    \     'start': '\e\[1m',
    \     'end': '\e\[22m',
    \     'hi': 'term=bold cterm=bold gui=bold',
    \ },
    \
    \ 'trans_boldunderlined': {
    \     'start': '\e\[4m\e\[1m',
    \     'end': '\e\[22m\e\[24m',
    \     'hi': 'term=bold,underline cterm=bold,underline gui=bold,underline',
    \ },
    \
    \ 'tldr_boldgreen': {
    \     'start': '\e\[32m\e\[1m',
    \     'end': '\e\[m\%x0f',
    \     'hi': 'term=bold cterm=bold gui=bold ctermfg=green guifg=#198844',
    \ },
    \
    \ 'tldr_italic': {
    \     'start': '\e\[3m',
    \     'end': '\e\[m\%x0f',
    \     'hi': 'term=italic cterm=italic gui=italic',
    \ },
    \
    \ 'tldr_bold': {
    \     'start': '\e\[1m',
    \     'end': '\e\[m\%x0f',
    \     'hi': 'term=bold cterm=bold gui=bold',
    \ },
    \ }

fu lg#textprop#ansi() abort "{{{1
    if !search('\e', 'cn') | return | endif
    let view = winsaveview()

    " Why do you use text properties and not regex-based syntax highlighting?{{{
    "
    " Using text properties allows us to remove the ansi codes.
    " This way, if we yank some line, we don't copy them.
    "}}}
    "   How would I get the same highlighting with syntax rules?{{{
    "
    " For the bold and bold+underlined attributes:
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
    let bufnr = bufnr('%')
    if has('nvim') | let id = nvim_create_namespace('ansi') | endif
    for [attr, v] in items(s:ATTR)
        exe 'hi ansi_'..attr..' '..v.hi
        call cursor(1, 1)
        let flags = 'cW'
        if !has('nvim')
            call prop_type_add('ansi_'..attr, #{highlight: 'ansi_'..attr, bufnr: bufnr})
            while search(v.start, flags) && search(v.end, 'n')
                let flags = 'W'
                call prop_add(line('.'), col('.'), #{
                    \ length: searchpos(v.end..'\zs', 'cn')[1] - col('.'),
                    \ type: 'ansi_'..attr,
                    \ })
            endwhile
        else
            while search(v.start, flags) && search(v.end, 'n')
                let flags = 'W'
                call nvim_buf_add_highlight(0, id, 'ansi_'..attr,
                    \ line('.')-1, col('.'), searchpos(v.end..'\zs', 'cn')[1]-1)
            endwhile
        endif
    endfor

    let clean_this = '\C\e\[\d*m\|[[:cntrl:]]'
    sil exe 'keepj keepp lockm %s/'..clean_this..'//ge'
    " Don't save the buffer.{{{
    "
    " It's useful to keep the file as it is, in case we want to send it to a Vim
    " server, and re-highlight the ansi escape codes in this other Vim instance.
    "}}}
    setl nomod
    call winrestview(view)
endfu

