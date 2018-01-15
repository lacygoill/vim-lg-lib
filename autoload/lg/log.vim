fu! lg#log#msg(what) abort "{{{1
    if has_key(a:what, 'msg')
        let excmd = a:what.excmd
        let msg = a:what.msg
        let title = a:what.title
    else
        let excmd = a:what.excmd
        let level = a:what.level
        "                                       ┌ if the level is 1, just write `:Verbose`
        "                                       │ instead of `:1Verbose`
        "               ┌───────────────────────┤
        let title = ':'.(level == 1 ? '' : level).'Verbose '.excmd
    endif

    let tempfile = tempname()
    call writefile([ title ], tempfile, 'b')
    "                                    │
    "                                    └─ use binary mode to NOT add a linefeed after the title
    " How do you know Vim adds a linefeed?{{{
    "
    " Watch:
    "         :!touch /tmp/file
    "         :call writefile(['text'], '/tmp/file')
    "         :!xxd /tmp/file
    "                 → 00000000: 7465 7874 0a    text.
    "                                       └┤        │
    "                                        │        └─ LF glyph
    "                                        └─ LF hex code
    "}}}

    try
        " We set 'vfile' to `tempfile`.
        " It will redirect (append) all messages to the end of this file.
        let &verbosefile = tempfile

        "                      ┌─ From `:h :verb`:
        "                      │
        "                      │          When concatenating another command,
        "                      │          the ":verbose" only applies to the first one.
        "                      │
        "                      │  We want `:Verbose` to apply to the whole “pipeline“.
        "                      │  Not just the part before the 1st bar.
        "                      │
        sil exe level.'verbose exe '.string(excmd)
        " │
        " └─ even though verbose messages are redirected to a file,
        "    regular messages are  still displayed on the  command-line;
        "    we don't want that
        "    Watch:
        "           Verbose ls
    catch
        return lg#catch_error()
    finally
        " We empty the value of 'vfile' for 2 reasons:
        "
        "     1. to restore the original value
        "
        "     2. writes are buffered, thus may not show up for some time
        "        Writing to the file ends when […] 'verbosefile' is made empty.
        "
        " These info are from `:h 'vfile'`.
        let &verbosefile = ''
    endtry

    " Load the file in the preview window. Useful to avoid having to close it if
    " we execute another `:Verbose` command. From `:h :ptag`:
    "         If a "Preview" window already exists, it is re-used
    "         (like a help window is).
    exe 'pedit '.tempfile

    " Vim doesn't give the focus to the preview window. Jump to it.
    wincmd P
    " if we really get there...
    if &previewwindow
        nno  <buffer><nowait><silent>  q  :<c-u>call lg#window#quit()<cr>
        setl bh=wipe bt=nofile nobl nowrap noswf
    endif
endfu
