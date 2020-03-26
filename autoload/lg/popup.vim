if exists('g:autoloaded_lg#popup')
    finish
endif
let g:autoloaded_lg#popup = 1

" `#create()` raises errors!{{{
"
" Make sure  you've used  the `row` key,  and not `line`,  to describe  the line
" address of the anchor.
"
" Also, don't use `minwidth`, `maxwidth`, `minheight`, `maxheight`.
" Just use `width` and `height`.
"}}}
" I have another issue with one of these functions!{{{
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
            return lg#popup#nvim#basic(what, opts)
        else
            return lg#popup#vim#basic(what, opts)
        endif
    elseif has_border && !is_term
        if has('nvim')
            return lg#popup#nvim#border(what, opts)
        else
            return lg#popup#vim#border(what, opts)
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

