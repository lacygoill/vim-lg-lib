" Purpose:{{{
"
" Derive a  new syntax group  (`to`) from  an existing one  (`from`), overriding
" some attributes (`newAttributes`).
"}}}
" Usage Examples:{{{
"
"     " create `CommentUnderlined` from `Comment`; override the `term`, `cterm`, and `gui` attributes
"     call lg#syntax#derive('CommentUnderlined', 'Comment', 'term=underline cterm=underline gui=underline')
"
"     " create `PopupSign` from `WarningMsg`; override the `guibg` or `ctermbg` attribute,
"     " using the colors of the `Normal` HG
"     call lg#syntax#derive('PopupSign', 'WarningMsg', {'bg': 'Normal'})
"}}}
fu lg#syntax#derive(to, from, newAttributes) abort
    let originalDefinition = s:getdef(a:from)
    " if the `from` syntax group is linked to another group, we need to resolve the link
    if originalDefinition =~# ' links to \S\+$'
        " Why the `while` loop?{{{
        "
        " Well, we don't know how many links there are; there may be more than one.
        " That is, the  `from` syntax group could be linked  to `A`, which could
        " be linked to `B`, ...
        "}}}
        let g = 0 | while originalDefinition =~# ' links to \S\+$' && g < 9 | let g += 1
            let link = matchstr(originalDefinition, ' links to \zs\S\+$')
            let originalDefinition = s:getdef(link)
            let originalGroup = link
        endwhile
    else
        let originalGroup = a:from
    endif
    let pat = '^'..originalGroup..'\|xxx'
    let l:Rep = {m -> m[0] is# originalGroup ? a:to : ''}
    let newAttributes = s:getattr(a:newAttributes, a:from)
    exe 'hi '
        \ ..substitute(originalDefinition, pat, l:Rep, 'g')
        \ ..' '..newAttributes
endfu

fu s:getdef(hg) abort
    " Why `filter(split(...))`?{{{
    "
    " The output of `:hi ExistingHG`  can contain noise in certain circumstances
    " (e.g. `-V15/tmp/log`, `-D`, `$ sudo`...).
    " }}}
    return filter(split(execute('hi '..a:hg), '\n'), {_,v -> v =~# '^'..a:hg })[0]
endfu

fu s:getattr(attr, hg) abort
    if type(a:attr) == type('')
        return a:attr
    elseif type(a:attr) == type({})
        let gui = has('gui_running') || &tgc
        let mode = gui ? 'gui' : 'cterm'
        let [attr, hg] = items(a:attr)[0]
        let code = synIDattr(synIDtrans(hlID(hg)), attr, mode)
        if code =~# '^'..(gui ? '#\x\+' : '\d\+')..'$'
            return mode..attr..'='..code
        endif
        return ''
    endif
endfu

