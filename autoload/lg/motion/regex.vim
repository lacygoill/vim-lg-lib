fu! lg#motion#regex#go(kwd, is_fwd, mode) abort "{{{1
    let cnt = v:count1
    let pat = get({
    \               '{{':    '\v\{{3}%(\d+)?\s*$',
    \               '#':     '^#\|^=',
    \               'fu':    '^\s*fu\%[nction]!\s\+',
    \               'endfu': '^\s*endfu\%[nction]\s*$',
    \               'path':  '\v%(\s\.%(\=|,))@!&%(^|\s)\zs[./~]\f+',
    \               'url':   '\vhttps?://',
    \             }, a:kwd, '')

    if empty(pat)
        return
    endif

    if a:mode ==# 'n'
        norm! m'
    elseif index(['v', 'V', "\<c-v>"], a:mode) >= 0
        " If we  were initially  in visual mode,  we've left it  as soon  as the
        " mapping pressed Enter  to execute the call to this  function.  We need
        " to get back in visual mode, before the search.
        norm! gv
    endif

    while cnt > 0
        call search(pat, a:is_fwd ? 'W' : 'bW')
        let cnt -= 1
    endwhile

    " If you  try to  simplify this  block in a  single statement,  don't forget
    " this: the function shouldn't do anything in operator-pending mode.
    if a:mode ==# 'n'
        norm! zMzv
    elseif index(['v', 'V', "\<c-v>"], a:mode) >= 0
        norm! zv
    endif
endfu

fu! lg#motion#regex#rhs(kwd, is_fwd) abort "{{{1
    "               ┌ necessary to get the full  name of the mode, otherwise in
    "               │ operator-pending mode, we would get 'n' instead of 'no'
    "               │
    let mode = mode(1)
    return printf(":\<c-u>call lg#motion#regex#go(%s,%d,%s)\<cr>",
    \             string(a:kwd), a:is_fwd, string(mode))
endfu
