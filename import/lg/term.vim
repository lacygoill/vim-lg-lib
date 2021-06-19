vim9script

# Why don't you move this function in `lg.vim`?{{{
#
# We  import it  from `colorscheme.vim`  which is  automatically sourced  during
# startup.   We  don't want  *all*  the  functions  in  `lg.vim` to  be  sourced
# automatically during startup.
#}}}

export def Termname(): string #{{{1
    if exists('$TMUX')
        return system('tmux display -p "#{client_termname}"')->trim("\n", 2)
    else
        return &term
    endif
enddef
