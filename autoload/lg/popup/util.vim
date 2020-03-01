fu lg#popup#util#get_borderchars() abort
    return ['─', '│', '─', '│', '┌', '┐', '┘', '└']
endfu

fu lg#popup#util#set_borderchars(opts) abort
    call extend(a:opts, #{borderchars: lg#popup#util#get_borderchars()}, 'keep')
endfu

fu lg#popup#util#is_terminal_buffer(n) abort
    return type(a:n) == type(0) && a:n > 0 && getbufvar(a:n, '&bt', '') is# 'terminal'
endfu

