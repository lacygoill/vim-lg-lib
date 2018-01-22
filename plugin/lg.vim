com!  -nargs=?  -complete=custom,lg#motion#repeatable#listing#complete
\     ListRepeatableMotions
\     call lg#motion#repeatable#listing#main(<q-args>)

com! -bar -range=1 -nargs=1 -complete=command Verbose
\                                             call lg#log#output({'level': <count>, 'excmd': <q-args>})
