fu! lg#catch_error() abort "{{{1
    if get(g:, 'my_verbose_errors', 0)
        let func_name = matchstr(v:throwpoint, 'function \zs.\{-}\ze,')
        let line = matchstr(v:throwpoint, 'function .\{-}, \zsline \d\+')

        echohl ErrorMsg
        echom 'Error detected while processing function '.func_name.':'
        echohl LineNr
        echom line.':'
    endif

    echohl ErrorMsg
    " Even if you set “my_verbose_errors”, when this function will be called
    " from a function implementing an operator  (g@), only the last message will
    " be visible (i.e. v:exception).
    " But  it  doesn't matter. All  the  messages  have  been written  in  Vim's
    " log. So, `:WTF` will be able to show us where the error comes from.
    echom v:exception
    echohl NONE

    " It's important  to return  an empty string. Because  often, the  output of
    " this function will be executed or inserted. Check `vim-interactive-lists`,
    " and `vim-readline`.
    return ''
endfu

fu! lg#man_k(pgm) abort "{{{1
    let cur_word = expand('<cword>')
    exe 'Man '.a:pgm

    try
        " populate location list
        exe 'lvim /\<\C'.cur_word.'\>/ %'
        " set its title
        call setloclist(0, [], 'a', { 'title': cur_word })

        let g:motion_to_repeat = ']l'
    catch
        try
            sil exe 'Man '.cur_word
        catch
            " If the word under the cursor is not present in any man page, quit.
            quit
            " FIXME:
            " If I hit `K` on a garbage word inside a shell script, the function
            " doesn't quit, because `:Man garbage_word` isn't considered an error.
            " If it was considered an error `:silent` wouldn't be enough to
            " hide the warning message. We would have to add a bang.
            " The problem comes from `man#open_page()` inside
            " ~/.vim/plugged/vim-man/autoload/man.vim
            "
            " When it receives an optional word as an argument, and there's no
            " manual page for it, the function calls `s:error()`. The latter
            " don't raise any exception. Maybe we could use `:throw`, although
            " I don't know how it works exactly. But then we would have errors
            " when we execute `:Man garbage_word` manually.
            "
            " Edit:
            " This whole code seems dubious. We  may silently ignore other valid
            " errors, because of these 2 nested try conditionals.
            " We should rethink this code.
        endtry
    endtry
endfu

