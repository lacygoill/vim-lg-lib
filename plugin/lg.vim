if exists('g:loaded_lg')
    finish
endif
let g:loaded_lg = 1

com -bar -nargs=? -complete=custom,lg#motion#repeatable#listing#complete
    \ RepeatableMotions
    \ call lg#motion#repeatable#listing#main(<q-args>)
