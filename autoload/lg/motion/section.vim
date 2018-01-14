if exists('g:autoloaded_lg#motion#section')
    finish
endif
let g:autoloaded_lg#motion#section = 1

" Why a guard?{{{
"
" We need to install a few `<plug>` mappings, for the functions to work.
"
" Big deal (/s) … So what?
"
" Rule: Any  interface element  (mapping, autocmd,  command), or  anything which
" change  the  state  of  the  environment of  a  plugin  (assignment,  call  to
" function like `call s:init()`), should be sourced only once.
"
" What's the reasoning behind this rule?
"
" Changing the  state of the environment  of the plugin during  runtime may have
" undesired effects, including bugs. Same thing for the interface.
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

" TODO:
" Add a guard in all autoloaded files which install an interface element,
" or which have a state (assign value to variable, call to function).
" Maybe leave a comment redirecting here, to explain the reasoning.
" Also, normalize their name: only 1 underscore, # for the rest.

" TODO:
" Review and explain how this code works.

fu! lg#motion#section#go(mode) abort "{{{1
    let args = split(input(''), '\zs')
    let is_fwd = args[0] ==# "\u2000" ? 1 : 0
    let pat = { "\u2000": '^\s*fu\%[nction]!\s\+',
    \           "\u2001": '^\s*endfu\%[nction]\s*$',
    \           "\u2002": '\v\{{3}%(\d+)?\s*$',
    \           "\u2003": '^#\|^=',
    \         }[args[1]]

    norm! m'

    " If we were initially in visual mode, we've left it as soon as the mapping
    " pressed Enter to execute the call to this function.
    " We need to get back in visual mode, before the search.
    if a:mode ==# 'x'
        norm! gv
    endif

    let c = v:count1
    while c > 0
        call search(pat, is_fwd ? 'W' : 'bW')
        let c -= 1
    endwhile

    if a:mode ==# 'n'
        norm! zMzv
    endif
endfu

fu! lg#motion#section#rhs(is_fwd, pat) abort "{{{1
    "               ┌ necessary to get the full  name of the mode, otherwise in
    "               │ operator-pending mode, we would get 'n' instead of 'no'
    "               │
    let mode = mode(1)
    let seq = index(['v', 'V', "\<c-v>"], mode) >= 0
    \?            "\<plug>(section-visual)"
    \:        mode ==# 'no'
    \?            "\<plug>(section-op)"
    \:            "\<plug>(section-normal)"

    " TODO:
    " Explain these unicode characters.
    " They are special kind of spaces.
    " We use them because their glyph isn't visible on the command-line.
    let seq .= (a:is_fwd ? "\u2000" : "\u2001")
    \         .{'fu': "\u2000", 'endfu': "\u2001", '{{' : "\u2002", '#': "\u2003"}[a:pat]
    \         ."\<cr>"

    " Why `feedkeys()`?{{{
    "
    " This function is used in an `<expr>` mapping.
    " But we  may need to  execute some  `:normal` commands, which  is forbidden
    " while the textlock is active.
    " So, we delegate the rest of the work to another function `lg#motion#section#go()`.
    " And we call the latter via a `<plug>` mapping.
    "}}}
    call feedkeys(seq, 'i')
    return ''
endfu

nno  <silent>  <plug>(section-normal)  :<c-u>call lg#motion#section#go('n')<cr>
xno  <silent>  <plug>(section-visual)  :<c-u>call lg#motion#section#go('x')<cr>
ono  <silent>  <plug>(section-op)      :<c-u>call lg#motion#section#go('o')<cr>
