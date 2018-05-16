if exists('g:loaded_lg')
    finish
endif
let g:loaded_lg = 1

com!  -nargs=?  -complete=custom,lg#motion#repeatable#listing#complete
\     ListRepeatableMotions
\     call lg#motion#repeatable#listing#main(<q-args>)
