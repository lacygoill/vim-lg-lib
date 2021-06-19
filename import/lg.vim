vim9script

export def Catch(): string #{{{1
    if get(g:, 'my_verbose_errors', false)
        var funcname: string = v:throwpoint->matchstr('function \zs.\{-}\ze,')
        var line: string = v:throwpoint->matchstr('\%(function \)\=.\{-}, \zsline \d\+')

        echohl ErrorMsg
        if !empty(funcname)
            unsilent echom 'Error detected while processing function ' .. funcname .. ':'
        else
            # the error comes from a (temporary?) file
            unsilent echom 'Error detected while processing ' .. v:throwpoint->matchstr('.\{-}\ze,') .. ':'
        endif
        echohl LineNr
        unsilent echom line .. ':'
    endif

    echohl ErrorMsg
    # Even if  you set  “my_verbose_errors”, when this  function will  be called
    # from a  function implementing  an operator (`g@`),  only the  last message
    # will be visible (i.e. `v:exception`).
    # But it doesn't  matter.  All the messages have been  written in Vim's log.
    # So, `:WTF` will be able to show us where the error comes from.
    unsilent echom v:exception
    echohl NONE

    # It's  important   to  return   an  empty   string.   Because   often,  the
    # output   of  this   function  will   be  executed   or  inserted.    Check
    # `vim-interactive-lists`, and `vim-readline`.
    return ''
enddef

export def FuncComplete( #{{{1
    arglead: string,
    _, _
): list<string>

    # Problem: `:breakadd`, `:def`, and `profile` don't complete function names.{{{
    #
    # This is especially annoying for names of script-local functions.
    #}}}
    # Solution: Implement a custom completion function which can be called from wrapper commands.{{{
    #
    # Example:
    #
    #     import FuncComplete from 'lg.vim'
    #     com -bar -complete=customlist,FuncComplete -nargs=? Def Def(<q-args>)
    #              ^-------------------------------^
    #}}}

    # We really need to return a list, and not a newline-separated list wrapped inside a string.{{{
    #
    # If we return a  string, then this completion function must  be called by a
    # custom command defined with the `-complete=custom` attribute.
    # But  if  `arglead`  starts  with  `s:`,   Vim  will  filter  out  all  the
    # candidates, because none of them would match `s:` at the start.
    #
    # We  must use  `-complete=customlist` to  disable the  filtering, and  that
    # means that this function must return a list, not a string.
    #
    #     com -bar -complete=custom,FuncComplete -nargs=? Def Def(<q-args>)
    #                        ^----^
    #                          ✘
    #
    #     com -bar -complete=customlist,FuncComplete -nargs=? Def Def(<q-args>)
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
    return arglead
        ->substitute('^\Cs:', '<SNR>[0-9]\\\\\\{1,}_', '')
        ->getcompletion('function')
        ->map((_, v: string): string => v->substitute('($\|()$', '', ''))
enddef

export def GetSelectionText(): list<string> #{{{1
    if mode() =~ "[vV\<c-v>]"
        return getreg('*', true, true)
    endif
    var reg_save: dict<any> = getreginfo('"')
    var clipboard_save: string = &clipboard
    var selection_save: string = &selection
    try
        &clipboard = ''
        &selection = 'inclusive'
        sil noa norm! gvy
        return getreg('"', true, true)
    catch
        echohl ErrorMsg | echom v:exception | echohl NONE
    finally
        setreg('"', reg_save)
        [&clipboard, &selection] = [clipboard_save, selection_save]
    endtry
    return []
enddef

export def GetSelectionCoords(): dict<list<number>> #{{{1
# Get the coordinates of the current visual selection without quitting visual mode.
    var mode: string = mode()
    if mode !~ "^[vV\<c-v>]$"
        return {}
    endif
    var curpos: list<number>
    var pos_v: list<number>
    var start: list<number>
    var end: list<number>
    [pos_v, curpos] = [getpos('v')[1 : 2], getcurpos()[1 : 2]]
    var control_end: bool = curpos[0] > pos_v[0]
                         || curpos[0] == pos_v[0] && curpos[1] >= pos_v[1]
    if control_end
        [start, end] = [pos_v, curpos]
    else
        [start, end] = [curpos, pos_v]
    endif
    # If the selection is linewise, the column positions are not what we expect.
    # Let's fix that.
    if mode == 'V'
        start[1] = 1
        # Why `getline(end[0])->...`?{{{
        #
        # From `:h col()`:
        #
        #    > $       the end of the cursor line (the result is the
        #    >         number of bytes in the cursor line **plus one**)
        #}}}
        end[1] = col([end[0], '$']) - (getline(end[0])->strlen() > 0 ? 1 : 0)
    # In case we've pressed `O`.{{{
    #
    # Otherwise, the  returned coordinates  would not  match the  upper-left and
    # bottom-right corners, but the upper-right and bottom-left corners.
    #
    # This would undoubtedly introduce some confusion in our plugins.
    # Let's make sure the function always return what we have in mind.
    #}}}
    elseif mode == "\<c-v>" && start[1] > end[1]
        [start[1], end[1]] = [end[1], start[1]]
    endif
    return {start: start, end: end}
enddef

export def InTerminalBuffer(): bool #{{{1
    return &buftype == 'terminal'
        # tmux terminal scrollback buffer captured in Vim via `capture-pane`
        || (&filetype == '' && expand('%:p') =~ '^$\|^\%(/proc/\|/tmp/\)' && search('^٪', 'n') > 0)
enddef

export def IsVim9(): bool #{{{1
    if &filetype != 'vim'
        return false
    endif

    var patdef: string = '^\C\s*\%(export\s\+\)\=def\>'

    # we're in the Vim9 context if the first command is `:vim9script`
    return getline(1) =~ '^vim9s\%[cript]\>'
        # ... unless we're in a legacy function
        && searchpair('^\C\s*fu\%[nction]\>', '', '^\C\s*\<endf\%[unction]\>$', 'nW') <= 0
        # in a legacy script, we're in the Vim9 context in a `:def` function
        || searchpair(patdef, '', '^\C\s*\<enddef\>$', 'nW') > 0
        # ... unless we're on its header line
        && getline('.') !~ patdef
        # FIXME: Being on the header doesn't necessarily mean that we're at the script level.
        # We could be on the header of a `:def` function nested in another `:def` function.
enddef

export def Opfunc(type: string) #{{{1
    if !exists('g:operatorfunc') || !g:operatorfunc->has_key('core')
        return
    endif

    var reg_save: dict<dict<any>>
    for regname in ['"', '-']
                 + range(10)->mapnew((_, v: number): string => string(v))
        reg_save[regname] = getreginfo(regname)
    endfor

    #     It might be necessary to save and restore `"0` if the unnamed register was
    #     originally pointing to some arbitrary register (e.g. `"r`).
    var clipboard_save: string = &clipboard
    var selection_save: string = &selection
    var visual_marks_save: list<list<number>> = [getpos("'<"), getpos("'>")]
    try
        &clipboard = ''
        &selection = 'inclusive'
        # Yanking may be useless for our operator function.{{{
        #
        # Worse, it could have undesirable side effects:
        #
        #    - reset `v:register`
        #    - reset `v:count`
        #    - mutate unnamed register
        #
        # See our `dr` operator for an example.
        #}}}
        if get(g:operatorfunc, 'yank', true)
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
            var commands: dict<string> = {
                char: '`[v`]y',
                line: "'[V']y",
                block: "`[\<c-v>`]y"
            }
            exe 'sil keepj norm! ' .. get(commands, type, '')
        endif
        call(g:operatorfunc.core, [type])
        # Do *not* remove `g:operatorfunc.core`.  It would break the dot command.
    catch
        Catch()
        return
    finally
        keys(reg_save)->mapnew((_, v: string) => setreg(v, reg_save[v]))
        [&clipboard, &selection] = [clipboard_save, selection_save]
        # Shouldn't we check the validity of the saved positions?{{{
        #
        # Indeed, the operator may have  removed the characters where the visual
        # marks were originally set, and the positions of the saved marks may be
        # invalid.  But in practice, it doesn't seem to raise any error:
        #
        #     $ vim -Nu NONE -i NONE +'echom setpos("'\''<", [0, 999, 999, 0])'
        #     0˜
        #}}}
        setpos("'<", visual_marks_save[0])
        setpos("'>", visual_marks_save[1])
    endtry
enddef

export def VimParent(): string #{{{1
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
        var winnr: number = range(1, winnr('$'))
            ->mapnew((_, v: number): bool => getwinvar(v, '&previewwindow'))
            ->index(true) + 1
        if winnr == 0
            return 0
        endif
        return win_getid(winnr)
    elseif arg == '#'
        var winnr: number = winnr('#')
        return win_getid(winnr)
    endif
    return 0
enddef

