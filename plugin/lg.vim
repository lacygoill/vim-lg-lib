com!  -nargs=?  -complete=custom,lg#motion#repeatable#listing#complete
\     ListRepeatableMotions
\     call lg#motion#repeatable#listing#main(<q-args>)

" Do NOT give the `-bar` attribute to `:Verbose`.{{{
"
" It would  prevent it  from working  correctly when  the command  which follows
" contains a bar:
"
"         :4Verbose cgetexpr system('grep -RHIinos pat * \| grep -v garbage')
"}}}
com! -range=1 -nargs=1 -complete=command  Verbose
\                                         call lg#log#output({'level': <count>, 'excmd': <q-args>})
