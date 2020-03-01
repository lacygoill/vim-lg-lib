if exists('g:autoloaded_lg#popup')
    finish
endif
let g:autoloaded_lg#popup = 1

fu lg#popup#create(what, opts) abort
    " For testing the function, you can use these values:{{{
    "
    " In a maximized terminal:
    "
    "     " Vim
    "     width = 107
    "     height = 19
    "     row = 8
    "     col = 7
    "
    "     " Nvim
    "     width = 107
    "     height = 19
    "     row = 7
    "     col = 6
    "
    " In a 80x24 terminal:
    "
    "     " Vim
    "     width = 72
    "     height = 14
    "     row = 6
    "     col = 5
    "
    "     " Nvim
    "     width = 72
    "     height = 14
    "     row = 5
    "     col = 4
    "}}}
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

