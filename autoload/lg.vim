fu lg#catch() abort "{{{1
    if get(g:, 'my_verbose_errors', 0)
        let func_name = matchstr(v:throwpoint, 'function \zs.\{-}\ze,')
        let line = matchstr(v:throwpoint, '\%(function \)\?.\{-}, \zsline \d\+')

        echohl ErrorMsg
        if !empty(func_name)
            echom 'Error detected while processing function '..func_name..':'
        else
            " the error comes from a (temporary?) file
            echom 'Error detected while processing '..matchstr(v:throwpoint, '.\{-}\ze,')..':'
        endif
        echohl LineNr
        echom line..':'
    endif

    echohl ErrorMsg
    " Even if  you set  “my_verbose_errors”, when this  function will  be called
    " from a  function implementing  an operator (`g@`),  only the  last message
    " will be visible (i.e. `v:exception`).
    " But it doesn't  matter.  All the messages have been  written in Vim's log.
    " So, `:WTF` will be able to show us where the error comes from.
    echom v:exception
    echohl NONE

    " It's  important   to  return   an  empty   string.   Because   often,  the
    " output   of  this   function  will   be  executed   or  inserted.    Check
    " `vim-interactive-lists`, and `vim-readline`.
    return ''
endfu

fu lg#opfunc(type) abort "{{{1
    if !exists('g:opfunc') || !has_key(g:opfunc, 'core')
        return
    endif
    let reg_save = getreginfo('"')
    let [cb_save, sel_save] = [&cb, &sel]
    let visual_marks_save = [getpos("'<"), getpos("'>")]
    try
        set cb= sel=inclusive
        " Yanking may be useless for our opfunc.{{{
        "
        " Worse, it could have undesirable side effects:
        "
        "    - reset `v:register`
        "    - reset `v:count`
        "    - mutate unnamed register
        "
        " See our `dr` operator for an example.
        "}}}
        if get(g:opfunc, 'yank', v:true)
            " Why do you use visual mode to yank the text?{{{
            "
            "     norm! `[y`]    ✘
            "     norm! `[v`]y   ✔
            "
            " Because  a  motion towards  a  mark  is  exclusive, thus  the  `y`
            " operator won't  yank the character  which is the nearest  from the
            " end of the buffer.
            "
            " OTOH,  ``v`]`` makes  this same  motion inclusive,  thus `y`  will
            " correctly yank all the characters in the text-object.
            " On the condition that `'selection'` includes `inclusive`.
            "}}}
            " Why `:noa`?{{{
            "
            " To minimize unexpected side effects.
            " E.g.,  it  prevents  our  visual   ring  from  saving  a  possible
            " selection, as  well as  the auto  highlighting when  we've pressed
            " `coy`.
            "}}}
            if a:type is# 'char'
                sil noa norm! `[v`]y
            elseif a:type is# 'line'
                sil noa norm! '[V']y
            elseif a:type is# 'block'
                sil noa exe "norm! `[\<c-v>`]y"
            endif
        endif
        call call(g:opfunc.core, [a:type])
        " Do *not* remove `g:opfunc.core`.  It would break the dot command.
    catch
        return lg#catch()
    finally
        call setreg('"', reg_save)
        let [&cb, &sel] = [cb_save, sel_save]
        " Shouldn't we check the validity of the saved positions?{{{
        "
        " Indeed, the operator may have  removed the characters where the visual
        " marks were originally set, and the positions of the saved marks may be
        " invalid.  But in practice, it doesn't seem to raise any error:
        "
        "     $ vim -Nu NONE -i NONE +'echom setpos("'\''<", [0, 999, 999, 0])'
        "     0~
        "}}}
        call setpos("'<", visual_marks_save[0])
        call setpos("'>", visual_marks_save[1])
    endtry
endfu

fu lg#getselection() abort "{{{1
    let reg_save = getreginfo('"')
    let [cb_save, sel_save] = [&cb, &sel]
    try
        set cb= sel=inclusive
        sil noa norm! gvy
        return getreg('"', 1, 1)
    catch
        echohl ErrorMsg | echom v:exception | echohl NONE
        return []
    finally
        call setreg('"', reg_save)
        let [&cb, &sel] = [cb_save, sel_save]
    endtry
endfu

fu lg#vim_parent() abort "{{{1
    "    ┌────────────────────────────┬─────────────────────────────────────┐
    "    │ :echo getpid()             │ print the PID of Vim                │
    "    ├────────────────────────────┼─────────────────────────────────────┤
    "    │ $ ps -p <Vim PID> -o ppid= │ print the PID of the parent of Vim  │
    "    ├────────────────────────────┼─────────────────────────────────────┤
    "    │ $ ps -p $(..^..) -o comm=  │ print the name of the parent of Vim │
    "    └────────────────────────────┴─────────────────────────────────────┘
    return system('ps -p $(ps -p '..getpid()..' -o ppid=) -o comm=')[:-2]
    " What's the difference with `$_`?{{{
    "
    " `$ ps -p ...` outputs the name of the *parent* of the current Vim process.
    " Generally, it's the name of your shell (`zsh`, `bash`, ...).
    " But it could also be `vipe`, `git`, ...
    "
    " `$_` evaluates to  the *full* name of the *command*  which was executed to
    " run the current Vim process.
    " Generally, it's the path to the Vim binary (e.g. `/usr/local/bin/vim`).
    " But it could also be `/usr/bin/vipe`, `/usr/bin/git`, ...
    "
    " Note that `$_` is  less costly, since you don't have  to spawn an external
    " process to evaluate it.
    "}}}
endfu

fu lg#termname() abort "{{{1
    if exists('$TMUX')
        return system('tmux display -p "#{client_termname}"')[:-2]
    else
        return $TERM
    endif
endfu

fu lg#win_getid(arg) abort "{{{1
    if a:arg is# 'P'
        let winnr = index(map(range(1, winnr('$')), {_,v -> getwinvar(v, '&pvw')}), 1) + 1
        if winnr == 0 | return 0 | endif
        return win_getid(winnr)
    elseif a:arg is# '#'
        let winnr = winnr('#')
        return win_getid(winnr)
    endif
endfu

