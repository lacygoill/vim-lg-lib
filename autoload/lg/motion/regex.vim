if exists('g:autoloaded_lg#motion#regex')
    finish
endif
let g:autoloaded_lg#motion#regex = 1

let s:patterns = {
                 \ '{{':              '\v\{{3}%(\d+)?\s*$',
                 \ '#':               '^#\|^=',
                 \ 'fu':              '^\s*fu\%[nction]!\s\+',
                 \ 'endfu':           '^\s*endf\%[unction]\%(\s\|"\|$\)',
                 \ 'sh_fu':           '^\s*\S\+\s*()\s*{\%(\s*#\s*{{'.'{\d*\s*\)\=$',
                 \ 'sh_endfu':        '^}$',
                 \ 'ref':             '\[.\{-1,}\](\zs.\{-1,})',
                 \ 'path':            '\v%(\s\.%(\=|,))@!&%(^|\s|`)\zs[./~]\f+',
                 \ 'url':             '\%(https\=\|ftps\=\|www\)://\|!\=\[.\{-}\]\%((.\{-})\|\[.\{-}\]\)',
                 \ 'concealed_url':   '\v\[.{-}\zs\]\(.{-}\)',
                 \ 'codespan':        '`.\{-1,}`',
                 \ }

fu! lg#motion#regex#go(kwd, is_fwd, mode) abort "{{{1
    let cnt = v:count1
    let pat = get(s:patterns, a:kwd, '')

    if empty(pat)
        return
    endif

    if a:mode is# 'n'
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

    " the function  shouldn't do anything in operator-pending mode
    if a:mode is# 'n' || index(['v', 'V', "\<c-v>"], a:mode) >= 0
        norm! zv
    endif
endfu

fu! lg#motion#regex#rhs(kwd, is_fwd) abort "{{{1
    "               ┌ necessary to get the full  name of the mode, otherwise in
    "               │ operator-pending mode, we would get 'n' instead of 'no'
    "               │
    let mode = mode(1)

    " If we're in visual block mode, we can't pass `C-v` directly.
    " It's going to by directly typed on the command-line.
    " On the command-line, `C-v` means:
    "
    "     “insert the next character literally”
    "
    " The solution is to double `C-v`.
    if mode is# "\<c-v>"
        let mode = "\<c-v>\<c-v>"
    endif

    return printf(":\<c-u>call lg#motion#regex#go(%s,%d,%s)\<cr>",
    \             string(a:kwd), a:is_fwd, string(mode))
endfu
