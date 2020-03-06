if exists('g:autoloaded_lg#popup')
    finish
endif
let g:autoloaded_lg#popup = 1

" I have an issue with one of these functions!{{{
"
" Switch `s:DEBUG` to 1 in `autoload/lg/popup/util.vim`.
" Reproduce your issue, then read the logfile.
"
" Check whether the code in the logfile looks ok.
" If it does, the issue may be due to a (N)Vim bug.
" Otherwise, if  some line seems wrong,  check out your source  code; start your
" search by pressing `C-w F` on the previous commented line.
"}}}

fu lg#popup#create(what, opts) abort "{{{1
    let [what, opts] = [a:what, a:opts]
    let has_border = has_key(opts, 'border')
    let is_term = has_key(opts, 'term') ? remove(opts, 'term') : v:false
    if !has_border && !is_term
        if has('nvim')
            return lg#popup#nvim#simple(what, opts)
        else
            return lg#popup#vim#simple(what, opts)
        endif
    elseif has_border && !is_term
        if has('nvim')
            return lg#popup#nvim#with_border(what, opts)
        else
            return lg#popup#vim#with_border(what, opts)
        endif
    elseif is_term
        if has('nvim')
            return lg#popup#nvim#terminal(what, opts)
        else
            return lg#popup#vim#terminal(what, opts)
        endif
    endif
endfu

fu lg#popup#notification(what, ...) abort "{{{1
    if has('nvim')
        call lg#popup#nvim#notification(a:what, a:0 ? a:1 : {})
    else
        call lg#popup#vim#notification(a:what, a:0 ? a:1 : {})
    endif
endfu

