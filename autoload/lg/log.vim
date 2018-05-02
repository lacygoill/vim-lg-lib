fu! lg#log#output(what) abort "{{{1
    " The dictionary passed to this function should have one of those set of keys:{{{
    "
    "       ┌ command we want to execute
    "       │ (to read its output in the preview window)
    "       │
    "       │      ┌ desired level of verbosity
    "       │      │
    "     • excmd, level    for :Verbose Cmd
    "     • excmd, lines    for :ListRepeatableMotions,
    "              │        or any custom command for which we manually build the output
    "              │
    "              └ lists of lines which we'll use as the output of the command
    "
"}}}
    if    !has_key(a:what, 'excmd')
    \ && (!has_key(a:what, 'level') || !has_key(a:what, 'lines'))
        return
    endif

    let tempfile = tempname()

    let excmd = a:what.excmd
    if has_key(a:what, 'lines')
        let title = ':'.excmd
        let lines = a:what.lines
        call writefile([title], tempfile, '')
        call writefile(lines, tempfile, 'ab')
    else
        let level = a:what.level
        "                                        ┌ if the level is 1, just write `:Verbose`
        "                                        │ instead of `:1Verbose`
        "               ┌────────────────────────┤
        let title = ':'.(level ==# 1 ? '' : level).'Verbose '.excmd
        call writefile([ title ], tempfile, 'b')
        "                                    │
        "                                    └─ use binary mode to NOT add a linefeed after the title
        " How do you know Vim adds a linefeed?{{{
        "
        " MWE:
        "         :!touch /tmp/file
        "         :call writefile(['text'], '/tmp/file')
        "         :!xxd /tmp/file
        "                 → 00000000: 7465 7874 0a    text.
        "                                       └┤        │
        "                                        │        └─ LF glyph
        "                                        └─ LF hex code
        "}}}

        " 1. `s:redirect_…()` executes `excmd`,
        "     and redirects its output in a temporary file
        "
        " 2. `type(…)` checks the output of `s:redirect_…()`
        "
        "        it should be `0`
        "        if, instead, it's a string, then an error has occurred: bail out
        if type(s:redirect_to_tempfile(tempfile, level, excmd)) ==# type('')
            return
        endif
    endif

    " Load the file in the preview window. Useful to avoid having to close it if
    " we execute another `:Verbose` command. From `:h :ptag`:
    "         If a "Preview" window already exists, it is re-used
    "         (like a help window is).
    exe 'pedit '.tempfile

    " Vim doesn't give the focus to the preview window. Jump to it.
    wincmd P
    " if we really got there …
    if &l:pvw
        setl bt=nofile nobl noswf nowrap
        nno  <buffer><nowait><silent>  q  :<c-u>call lg#window#quit()<cr>
        call lg#window#openable_anywhere()
    endif
endfu

fu! s:redirect_to_tempfile(tempfile, level, excmd) abort "{{{1
    try
        " We set 'vfile' to `tempfile`.
        " It will redirect (append) all messages to the end of this file.
        let &vfile = a:tempfile

        "                        ┌─ From `:h :verb`:
        "                        │
        "                        │          When concatenating another command,
        "                        │          the ":verbose" only applies to the first one.
        "                        │
        "                        │  We want `:Verbose` to apply to the whole “pipeline“.
        "                        │  Not just the part before the 1st bar.
        "                        │
        sil exe a:level.'verbose exe '.string(a:excmd)
        " │
        " └─ even though verbose messages are redirected to a file,
        "    regular messages are  still displayed on the  command-line;
        "    we don't want that
        "    MWE:
        "           Verbose ls
    catch
        return lg#catch_error()
    finally
        " We empty the value of 'vfile' for 2 reasons:
        "
        "     1. to restore the original value
        "
        "     2. writes are buffered, thus may not show up for some time
        "        Writing to the file ends when […] 'vfile' is made empty.
        "
        " These info are from `:h 'vfile'`.
        let &vfile = ''
    endtry
    return 0
endfu
