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

fu! lg#motion#section#go() abort "{{{1
    let cnt = v:count1
    let args = split(input(''), '\zs')

    let is_fwd = args[0] ==# "\u2001" ? 1 : 0

    let mode = get({
    \                "\u2001": 'n',
    \                "\u2002": 'x',
    \                "\u2003": 'o',
    \              }, args[1], '')

    let pat = get({
    \               "\u2001": '^\s*fu\%[nction]!\s\+',
    \               "\u2002": '^\s*endfu\%[nction]\s*$',
    \               "\u2003": '\v\{{3}%(\d+)?\s*$',
    \               "\u2004": '^#\|^=',
    \             }, args[2], '')

    if empty(mode) || empty(pat)
        return
    endif

    norm! m'

    " If we were initially in visual mode, we've left it as soon as the mapping
    " pressed Enter to execute the call to this function.
    " We need to get back in visual mode, before the search.
    if mode ==# 'x'
        norm! gv
    endif

    while cnt > 0
        call search(pat, is_fwd ? 'W' : 'bW')
        let cnt -= 1
    endwhile

    " If you  try to  simplify this  block in a  single statement,  don't forget
    " this: the function shouldn't do anything in operator-pending mode.
    if mode ==# 'n'
        norm! zMzv
    elseif mode ==# 'x'
        norm! zv
    endif
endfu

fu! lg#motion#section#rhs(is_fwd, pat) abort "{{{1
    "               ┌ necessary to get the full  name of the mode, otherwise in
    "               │ operator-pending mode, we would get 'n' instead of 'no'
    "               │
    let mode = mode(1)
    let seq = "\<plug>(lg-motion-section)"

    " TODO:
    " Explain these unicode characters.
    " They are special kind of spaces.
    " We use them because their glyph isn't visible on the command-line.

    let seq .= (a:is_fwd ? "\u2001" : "\u2000")
    \
    \         .get({ 'n':      "\u2001",
    \                'v':      "\u2002",
    \                'V':      "\u2002",
    \                "\<c-v>": "\u2002",
    \                'no':     "\u2003" }, mode, 'invalid')
    \
    \         .get({ 'fu':    "\u2001",
    \                'endfu': "\u2002",
    \                '{{':    "\u2003",
    \                '#':     "\u2004", }, a:pat, 'invalid')
    \
    \         ."\<cr>"

    if seq !~# 'invalid.\?\r'
        " Why `feedkeys()`?{{{
        "
        " This function  is used  in an  `<expr>` mapping.  But  we may  need to
        " execute some `:normal` commands, which is forbidden while the textlock
        " is active.
        "
        " So,  we   delegate  the   rest  of  the   work  to   another  function
        " `lg#motion#section#go()`.   And  we call  the  latter  via a  `<plug>`
        " mapping.
        "}}}
        " Why not a timer?{{{
        "
        " It would indeed make the code much simpler.
        "
        " No need to install a `<plug>` mapping to call the 2nd function:
        " we could call it directly.
        " No need to write special whitespace in the typeahead buffer:
        " we could pass them directly too.
        " The 2nd function could be local to the script instead of public.
        "
        " However,  it seems  it  would break  the  mapping in  operator-pending
        " mode. Besides,  in visual  mode,  we would  need  to redraw  (probably
        " because of the previous textlock).
        "}}}
        call feedkeys(seq, 'i')
    endif
    return ''
endfu

noremap  <silent>  <plug>(lg-motion-section)  :<c-u>call lg#motion#section#go()<cr>
