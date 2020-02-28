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
    " TODO: check whether 'siso' needs to be reset to 0 in Nvim
    if !has_border && !is_term
        if has('nvim')
            call lg#popup#nvim#simple(what, opts)
        else
            call lg#popup#vim#simple(what, opts)
        endif
    elseif has_border && !is_term
        if has('nvim')
            call remove(opts, 'border')
            call lg#popup#nvim#with_border(what, opts)
        else
            call lg#popup#vim#with_border(what, opts)
        endif
    elseif is_term
        " TODO: make sure a border is drawn no matter what (choose a default one if necessary)
        if has('nvim')
            if has_key(opts, 'border') | call remove(opts, 'border') | endif
            call lg#popup#nvim#terminal(what, opts)
        else
            call lg#popup#vim#terminal(what, opts)
        endif
    endif
endfu

