vim9script

export def Catch(): string #{{{1
    if get(g:, 'my_verbose_errors', 0)
        let func_name = matchstr(v:throwpoint, 'function \zs.\{-}\ze,')
        let line = matchstr(v:throwpoint, '\%(function \)\=.\{-}, \zsline \d\+')

        echohl ErrorMsg
        if !empty(func_name)
            echom 'Error detected while processing function ' .. func_name .. ':'
        else
            # the error comes from a (temporary?) file
            echom 'Error detected while processing ' .. matchstr(v:throwpoint, '.\{-}\ze,') .. ':'
        endif
        echohl LineNr
        echom line .. ':'
    endif

    echohl ErrorMsg
    # Even if  you set  “my_verbose_errors”, when this  function will  be called
    # from a  function implementing  an operator (`g@`),  only the  last message
    # will be visible (i.e. `v:exception`).
    # But it doesn't  matter.  All the messages have been  written in Vim's log.
    # So, `:WTF` will be able to show us where the error comes from.
    echom v:exception
    echohl NONE

    # It's  important   to  return   an  empty   string.   Because   often,  the
    # output   of  this   function  will   be  executed   or  inserted.    Check
    # `vim-interactive-lists`, and `vim-readline`.
    return ''
enddef

export def FuncComplete(argLead: string, _l: string, _p: number): list<string> #{{{1
    # Problem: `:breakadd`, `:def`, and `profile` don't complete function names.{{{
    #
    # This is especially annoying for names of script-local functions.
    #}}}
    # Solution: Implement a custom completion function which can be called from wrapper commands.{{{
    #
    # Example:
    #
    #     import FuncComplete from 'lg.vim'
    #     com -bar -complete=customlist,s:FuncComplete -nargs=? Def exe s:def(<q-args>)
    #              ^---------------------------------^
    #}}}

    # We really need to return a list, and not a newline-separated list wrapped inside a string.{{{
    #
    # If we return a  string, then this completion function must  be called by a
    # custom command defined with the `-complete=custom` attribute.
    # But  if  `argLead`  starts  with  `s:`,   Vim  will  filter  out  all  the
    # candidates, because none of them would match `s:` at the start.
    #
    # We  must use  `-complete=customlist` to  disable the  filtering, and  that
    # means that this function must return a list, not a string.
    #
    #     com -bar -complete=custom,s:FuncComplete -nargs=? Def exe s:def(<q-args>)
    #                        ^----^
    #                          ✘
    #
    #     com -bar -complete=customlist,s:FuncComplete -nargs=? Def exe s:def(<q-args>)
    #                        ^--------^
    #                            ✔
    #
    #}}}
    # Wait.  Why 6 backslashes in the replacement?{{{
    #
    # To emulate the `+` quantifier.  From `:h file-pattern`:
    #
    #    > \\\{n,m\}  like \{n,m} in a |pattern|
    #
    # Note that 3 backslashes are already neededd  in a file pattern, which is a
    # kind of globbing used by `getcompletion()`.
    # And since we write this in the replacement part of `substitute()`, we need
    # to double each backslash; hence 3 x 2 = 6 backslashes.
    #}}}
    return substitute(argLead, '^\Cs:', '<SNR>[0-9]\\\\\\{1,}_', '')
        \ ->getcompletion('function')
        \ ->map({_, v -> substitute(v, '($\|()$', '', '')})
enddef

export def GetSelection(): list<string> #{{{1
    let reg_save = getreginfo('"')
    let cb_save = &cb
    let sel_save = &sel
    try
        set cb= sel=inclusive
        sil noa norm! gvy
        return getreg('"', 1, 1)
    catch
        echohl ErrorMsg | echom v:exception | echohl NONE
    finally
        setreg('"', reg_save)
        [&cb, &sel] = [cb_save, sel_save]
    endtry
    return []
enddef

export def IsVim9(): bool #{{{1
    if &ft != 'vim'
        return false
    endif

    # we're in the Vim9 context if the first command is `:vim9script`
    return getline(1) == 'vim9script'
        # ... unless we're in a legacy function
        && searchpair('^\C\s*fu\%[nction]\>', '', '^\C\s*\<endf\%[unction]\>$', 'nW') <= 0
        # in a legacy script, we're in the Vim9 context in a `:def` function
        || searchpair('^\C\s*def\>', '', '^\C\s*\<enddef\>$', 'nW') > 0
        # ... unless we're on its header line
        && getline('.') !~ '^\s*def\>'
enddef

export def Opfunc(type: string) #{{{1
    if !exists('g:opfunc') || !has_key(g:opfunc, 'core')
        return
    endif
    let reg_save = getreginfo('"')
    let cb_save = &cb
    let sel_save = &sel
    let visual_marks_save = [getpos("'<"), getpos("'>")]
    try
        set cb= sel=inclusive
        # Yanking may be useless for our opfunc.{{{
        #
        # Worse, it could have undesirable side effects:
        #
        #    - reset `v:register`
        #    - reset `v:count`
        #    - mutate unnamed register
        #
        # See our `dr` operator for an example.
        #}}}
        if get(g:opfunc, 'yank', v:true)
            # Why do you use visual mode to yank the text?{{{
            #
            #     norm! `[y`]    ✘
            #     norm! `[v`]y   ✔
            #
            # Because  a  motion towards  a  mark  is  exclusive, thus  the  `y`
            # operator won't  yank the character  which is the nearest  from the
            # end of the buffer.
            #
            # OTOH,  ``v`]`` makes  this same  motion inclusive,  thus `y`  will
            # correctly yank all the characters in the text-object.
            # On the condition that `'selection'` includes `inclusive`.
            #}}}
            # Why `:noa`?{{{
            #
            # To minimize unexpected side effects.
            # E.g.,  it  prevents  our  visual   ring  from  saving  a  possible
            # selection, as  well as  the auto  highlighting when  we've pressed
            # `coy`.
            #}}}
            let commands = #{char: '`[v`]y', line: "'[V']y", block: "`[\<c-v>`]y"}
            sil exe 'keepj norm! ' .. get(commands, type, '')
        endif
        call(g:opfunc.core, [type])
        # Do *not* remove `g:opfunc.core`.  It would break the dot command.
    catch
        Catch()
        return
    finally
        setreg('"', reg_save)
        [&cb, &sel] = [cb_save, sel_save]
        # Shouldn't we check the validity of the saved positions?{{{
        #
        # Indeed, the operator may have  removed the characters where the visual
        # marks were originally set, and the positions of the saved marks may be
        # invalid.  But in practice, it doesn't seem to raise any error:
        #
        #     $ vim -Nu NONE -i NONE +'echom setpos("'\''<", [0, 999, 999, 0])'
        #     0~
        #}}}
        setpos("'<", visual_marks_save[0])
        setpos("'>", visual_marks_save[1])
    endtry
enddef

export def Vim_parent(): string #{{{1
#    ┌────────────────────────────┬─────────────────────────────────────┐
#    │ :echo getpid()             │ print the PID of Vim                │
#    ├────────────────────────────┼─────────────────────────────────────┤
#    │ $ ps -p <Vim PID> -o ppid= │ print the PID of the parent of Vim  │
#    ├────────────────────────────┼─────────────────────────────────────┤
#    │ $ ps -p $(..^..) -o comm=  │ print the name of the parent of Vim │
#    └────────────────────────────┴─────────────────────────────────────┘
    return system('ps -p $(ps -p ' .. getpid() .. ' -o ppid=) -o comm=')->trim("\n", 2)
    # What's the difference with `$_`?{{{
    #
    # `$ ps -p ...` outputs the name of the *parent* of the current Vim process.
    # Generally, it's the name of your shell (`zsh`, `bash`, ...).
    # But it could also be `vipe`, `git`, ...
    #
    # `$_` evaluates to  the *full* name of the *command*  which was executed to
    # run the current Vim process.
    # Generally, it's the path to the Vim binary (e.g. `/usr/local/bin/vim`).
    # But it could also be `/usr/bin/vipe`, `/usr/bin/git`, ...
    #
    # Note that `$_` is  less costly, since you don't have  to spawn an external
    # process to evaluate it.
    #}}}
enddef

export def Win_getid(arg: string): number #{{{1
    if arg == 'P'
        let winnr = range(1, winnr('$'))
            ->map({_, v -> getwinvar(v, '&pvw')})
            ->index(1) + 1
        if winnr == 0 | return 0 | endif
        return win_getid(winnr)
    elseif arg == '#'
        let winnr = winnr('#')
        return win_getid(winnr)
    endif
    return 0
enddef

