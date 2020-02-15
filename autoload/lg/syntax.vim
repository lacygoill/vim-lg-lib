" Purpose:
" Derive a  new syntax group  (`to`) from  an existing one  (`from`), overriding
" some attributes (`new_attributes`).
fu lg#syntax#derive(from, to, new_attributes) abort
    " Why `filter(split(...))`?{{{
    "
    " The output of `:hi ExistingHG`  can contain noise in certain circumstances
    " (e.g. `-V15/tmp/log`, `-D`, `$ sudo`...).
    " }}}
    let old_attributes = join(map(split(a:new_attributes), {_,v -> substitute(v, '=\S*', '', '')}), '\|')
    let originalDefinition = filter(split(execute('hi '..a:from), '\n'), {_,v -> v =~# '^'..a:from })[0]
    " the `from` syntax group is linked to another group
    if originalDefinition =~# ' links to \S\+$'
        " Why the `while` loop?{{{
        "
        " Well, we don't know how many links there are; there may be more than one.
        " That is, the  `from` syntax group could be linked  to `A`, which could
        " be linked to `B`, ...
        "}}}
        let g = 0 | while originalDefinition =~# ' links to \S\+$' && g < 9 | let g += 1
            let link = matchstr(originalDefinition, ' links to \zs\S\+$')
            let originalDefinition = filter(split(execute('hi '..link), '\n'), {_,v -> v =~# '^'..link })[0]
            let originalGroup = link
        endwhile
    else
        let originalGroup = a:from
    endif
    let pat = '^'..originalGroup..'\|xxx\|\<\%('..old_attributes..'\)=\S*'
    let l:Rep = {m -> m[0] is# originalGroup ? a:to : ''}
    exe 'hi '
        \ ..substitute(originalDefinition, pat, l:Rep, 'g')
        \ ..' '..a:new_attributes
endfu

