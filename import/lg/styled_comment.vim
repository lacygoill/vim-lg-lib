vim9script

# If you have an issue, have a look at `GetCommentgroup()`.{{{
#
# It should return a set of syntax groups which can highlight various type of comments.
#
# Open the default syntax plugin and search for:
#
#     x[^, \t]*comment
#     ^
#     replace with the filetype you have an issue with
#
# In the value returned by `GetCommentgroup()`, include as many groups as you found.
# }}}
# Whenever you create or remove a custom syntax group from `Syntax()`, update `CUSTOM_GROUPS`!{{{
#
# Otherwise, you may have a broken syntax highlighting in any filetype whose
# default syntax plugin uses `ALLBUT`.
#
# `CUSTOM_GROUPS` is used by `FixAllbut()` to define `@xMyCustomGroups`.
# We use this cluster to exclude our  custom groups from the ones installed by a
# default syntax plugin.
# In the future, it may be useful in a `after/syntax/x.vim`.
#}}}
# Regarding languages where the comment leader can have two parts:{{{
#
# Most of them have two kinds of comment leaders:
#
#    - one for single-line comments (e.g. `--` in lua)
#    - one for multi-line comments (e.g. `--[[`  and `--]]` in lua)
#
# **Always use the first version**, even for multi-line comments.
#
# Trying to support the second one adds too much complexity in this plugin.
# Not to mention in `vim-comment`.
# Worse,  it's probably  impossible to  apply the  desired highlighting  in some
# situations, when using the second version:
#
#     /* foo
#            should be highlighted as a codeblock; good luck!
#        bar
#      */
#
# Besides, it doesn't seem to add enough benefits.
# Also, from page 17 of “C Programming A Modern Approach”:
#
#    > The  newer comment  style  has  a couple  of  important advantages.   First,
#    > because  a comment  automatically ends  at  the end  of a  line, there's  no
#    > chance  that an  unterminated comment  will accidentally  consume part  of a
#    > program. Second,  multiline comments  stand  out better,  thanks  to the  //
#    > that's required at the beginning of each line.
#
# There are 2 notable exceptions: html and css.
# They only provide a syntax for multi-line comments.
# To get  an idea of how you would  have to refactor this file if  you wanted to
# support them, see this old commit:
# https://github.com/lacygoill/vim-lg-lib/commit/7d309f78900b63df6f8989fbc929660cda76d076
# }}}

# Init {{{1

const BLACKLIST =<< trim END
    css
    html
END

var allbut_groups: dict<list<string>>

const CUSTOM_GROUPS =<< trim END
    CommentBlockquote
    CommentBlockquoteBold
    CommentBlockquoteBoldItalic
    CommentBlockquoteCodeSpan
    CommentBlockquoteConceal
    CommentBlockquoteItalic
    CommentBold
    CommentBoldItalic
    CommentCodeBlock
    CommentCodeSpan
    CommentIgnore
    CommentItalic
    CommentKey
    CommentLeader
    CommentListItem
    CommentListItemBlockquote
    CommentListItemBlockquoteConceal
    CommentListItemBold
    CommentListItemBoldItalic
    CommentListItemCodeBlock
    CommentListItemCodeSpan
    CommentListItemItalic
    CommentOption
    CommentOutput
    CommentPointer
    CommentRule
    CommentTable
    CommentTitle
    CommentTitleLeader
    CommentUrl
    FoldMarkers
    @CommentListItemElements
END
# }}}1

# filetype plugin {{{1
export def Fold() #{{{2
    var ft = expand('<amatch>')
    # Do *not* remove this function call.{{{
    #
    # Yes, it  seems redundant,  because it  will be called  a second  time when
    # `BufWinEnter` will be fired right after `FileType`.
    #
    # But if you don't set the options now, it may lead to subtle issues; we had
    # one in the past in `vim-fold` when we used a timer to delay `setl fdm=manual`.
    # Anyway, if  these options  were in  a filetype plugin,  they would  be set
    # *right now*,  not slightly later; so  let's be consistent; let's  set them
    # right now.
    #}}}
    FoldSettings()
    # Why naming the augroup `MyFold_X` instead of just `My_X`?{{{
    #
    # Suppose you install this autocmd in `after/ftplugin/x.vim`:
    #
    #     augroup My_X
    #         au! * <buffer>
    #         au BufWinEnter " do sth
    #     augroup END
    #
    # It will be removed by the `au! * <buffer>` from the next autocmd.
    #
    # Indeed, in your vimrc, you have run `:filetype plugin on`, or vim-plug has
    # done it for you.
    # And  a bit  later, still  in  your vimrc,  you have  installed an  autocmd
    # listening to `FileType`  which calls the current function  (the augroup is
    # named `StyledComments`).
    #
    # So,   when  `FileType`   is   fired,  all   the   ftplugins  are   sourced
    # first  (including  the  ones  in   `after/`),  *then*  the  autocmds  from
    # `StyledComments` are run.
    #}}}
    # Why setting those options from an autocmd?{{{
    #
    # I tried  setting them directly, without  an autocmd; it works  most of the
    # time, but  when I  load a  buffer in  a window,  while it's  already being
    # displayed in another window, the options are often not applied.
    #
    # I think that's due to:
    # https://github.com/vim/vim/issues/4994
    #}}}
    exe 'augroup MyFold_' .. ft
        au! * <buffer>
        # Why `FileChangedShellPost`?{{{
        #
        # Without, the folding would be lost when:
        #
        #    - we write a file owned by root with `:W`
        #    - we stash some changes with `$ git stash`
        #}}}
        au BufWinEnter,FileChangedShellPost <buffer> FoldSettings()
    augroup END
enddef

def FoldSettings()
    # Why this guard?{{{
    #
    # Without, our fold settings may be unexpectedly applied in a qf buffer.
    # Remember that, at the moment, we fold help buffers with the foldmethod "marker".
    #
    # MWE:
    #
    #     $ vim -Nu NONE -es -S <(cat <<'EOF'
    #         au QuickFixCmdPost * au BufWinEnter * ++once lw
    #         au FileType help au BufWinEnter <buffer> setl fdm=marker
    #         lh foobar
    #         getloclist(0, {"winid": 0}).winid->win_gotoid()
    #         set vbs=1|echo &l:fdm
    #         qa!
    #     EOF
    #     )
    #     marker~
    #     " it should be "manual"
    #
    # Obviously, if  `'fdm'` is wrongly set  to "marker", and the  text field of
    # some entry contains a fold marker, the qf buffer gets folded.
    # This  can  have another  unexpected  side effect;  there  may be  a  weird
    # interaction with `vim-window` which makes the current line in the location
    # window wrong after `:llast`.
    #
    # ---
    #
    # The issue disappears if you remove the `BufWinEnter` autocmd:
    #
    #     au FileType help au BufWinEnter <buffer> setl fdm=marker
    #     →
    #     au FileType help setl fdm=marker
    #
    # ---
    #
    # I can't find anything wrong in our original code (without the guard).
    # I think the issue is due to some special code related to `:lh`.
    #
    # ---
    #
    # If you have other similar issues in the future, try this refactoring:
    #
    #     FoldSettings()
    #     →
    #     FoldSettings(ft)
    #                  ^^
    #
    #     au BufWinEnter,FileChangedShellPost <buffer> FoldSettings()
    #     →
    #     exe 'au BufWinEnter,FileChangedShellPost <buffer> FoldSettings(' .. string(ft) .. ')'
    #     ^---^                                                          ^--------------------^
    #
    #     fu FoldSettings() abort
    #     →
    #     fu FoldSettings(ft) abort
    #                     ^^
    #
    #     if &ft == 'qf' | return | endif
    #     →
    #     if &ft != ft | return | endif
    #        ^-------^
    #}}}
    if &ft == 'qf' | return | endif

    setl fdm=marker
    setl fdt=fold#fdt#get()
    setl cocu=nc
    setl cole=3
enddef

export def UndoFtplugin() #{{{2
    var ft = expand('<amatch>')
    b:undo_ftplugin = get(b:, 'undo_ftplugin', 'exe')
        .. '| set cocu< cole< fdm< fdt< | exe "au! MyFold_' .. ft .. ' * <buffer>"'
enddef
# }}}1
# syntax plugin {{{1
export def Syntax() #{{{2
    # Use `\s` instead of ` `!{{{
    #
    # This is necessary for a whitespace before a comment leader:
    #
    #     /^ ...
    #       ^
    #       ✘
    #
    #     /^\s...
    #       ^^
    #       ✔
    #
    # Because, there's  no guarantee  that the file  you're reading  is indented
    # with spaces.
    # To be consistent, we should always use `\s`, even for a whitespace *after*
    # the comment leader.
    #
    # ` {,N}` is an exception.  I think it's ok to use a literal space in this case.
    # Tpope does it a few times in his markdown syntax plugin.
    #}}}

    # Never write `matchgroup=xGroup` with `xGroup` being a builtin HG.{{{
    #
    # `xGroup` should be a *custom* HG, that we can customize in our colorscheme.
    # This function should *not* be charged with setting the colors of the comments.
    # It should only set the syntax.
    # This  way, we  can  change the  color  of a  type  of comment  (codeblock,
    # blockquote,  table,... ),  uniformly across  all filetypes  from a  single
    # location:
    #
    #     ~/.vim/autoload/colorscheme.vim
    #}}}
    # Be careful before using `^\s*` in a regex!{{{
    #
    # Some default syntax plugins define a  comment from the comment leader, not
    # from the beginning of the line,  either by omitting `^\s*` or by excluding
    # it with `\zs`.
    #
    #     $VIMRUNTIME/syntax/sh.vim:376
    #     $VIMRUNTIME/syntax/lua.vim:34
    #
    # Besides, all your custom items are contained in a comment.
    # If you define one of them with  `^\s*` it will begin from the beginning of
    # the line.
    # But if the line is indented,  the comment will begin *after* the beginning
    # of the line,  which will prevent your custom item  from being contained in
    # the comment.
    # As a result, its syntax highlighting will be broken.
    #
    # Atm, this issue applies to:
    #
    # - CommentBlockquote
    # - CommentCodeBlock
    # - CommentListItem
    # - CommentPointer
    # - CommentTable
    #}}}
    # What if I need `^\s*`?{{{
    #
    # Exclude it from the item with `\%(...\)\@<=`.
    # Make some tests with `:syntime` to measure the impact on performance.
    #}}}
    # Is it ok if I omit `^\s*`?{{{
    #
    # I think it's ok, because:
    #
    # 1. all these groups are contained in a comment;
    #    so if an undesired match could occur, it would be in a comment
    #
    # 2. they match whole lines (up to the end) from the first comment leader;
    #    so if an undesired match could occur, it would be in the item itself
    #
    # 3. they don't contain themselves
    #
    # Exception:
    #
    # For  `CommentListItem`, you  *have* to  use `\%(^\s*\)\@<=`,  probably
    # because it's a multi-line item.
    # Otherwise, you could  have an undesired list starting  from the middle
    # of a comment.
    #
    # Example in a lua file:
    #
    #     -- some comment -- - wrongly highlighted as list item
    #                        ^--------------------------------^
    #}}}

    # TODO: integrate most of the comments from this function into our notes

    # TODO: find a consistent order for the arguments of a region (and other items)
    # and stick to it (here and in the markdown syntax plugin)

    var ft = GetFiletype()
    var cml: string
    var cml_0_1: string
    var nr: number
    # for Vim, we need to handle 2 possible comment leaders (`#` is for Vim9 script)
    if &ft == 'vim'
        cml = '\%(#\|"\\\=\)'
        cml_0_1 = cml .. '\='
        nr = 1
    else
        cml = matchstr(&l:cms, '\S*\ze\s*%s')
        # What do you need this `nr` for?{{{
        #
        # For offsets when defining the syntax groups:
        #
        #    - xxxCommentTitle
        #    - xxxCommentTitleLeader
        #}}}
        # Why capturing it now?{{{
        #
        # The next statement  invokes `escape()` which may  add backslashes, and
        # alter the real number of characters inside the comment leader.
        #}}}
        nr = strchars(cml, 1)
        # Why do you escape the slashes?{{{
        #
        # We use a slash as a delimiter around the patterns of our syntax elements.
        # As a result, if the comment  leader of the current filetype contains a
        # slash, we need to escape the  slashes to prevent Vim from interpreting
        # them as the end of the pattern.
        # This is needed for `xkb` where the comment leader is `//`.
        #}}}
        cml = escape(cml, '\/')
        cml_0_1 = '\V\%(' .. cml .. '\)\=\m'
        cml = '\V' .. cml .. '\m'
    endif
    var commentGroup = GetCommentgroup(ft)

    SynCommentleader(ft, cml)
    SynCommenttitle(ft, cml, nr)
    # Why this guard? {{{
    #
    # For some filetypes, such as html  and css, it's too difficult to implement
    # some styles without any undesirable side effects.
    # }}}
    if index(s:BLACKLIST, ft) == -1
        SynListItem(ft, cml, commentGroup)
        # Don't move the call to `syn_code_block()` somewhere below!{{{
        #
        # `xCommentPointer` must be defined *after* `xCommentCodeBlock`.
        #
        # Otherwise its  highlighting would  fail when the  pointer is  located more
        # than 4 characters away from the comment leader.
        # I suspect there are other items which may sometimes break if they're defined
        # before `xCommentCodeBlock`.
        #
        # So, unless you know what you're doing, leave this call here.
        #}}}
        SynCodeBlock(ft, cml, commentGroup)
        SynBlockquote(ft, cml, commentGroup)
        SynTable(ft, cml, commentGroup)
        SynOutput(ft, cml)
        SynRule(ft, cml, commentGroup)
        SynPointer(ft, cml, commentGroup)
    endif
    SynCodeSpan(ft, commentGroup)
    # Don't change the order of `SynItalic()`, `SynBold()` and `SynBolditalic()`!{{{
    #
    # It would break the syntax highlighting of some style (italic, bold, bold+italic).
    #
    # Indeed,   we  haven't   defined   the   syntax  groups   `xCommentItalic`,
    # `xCommentBold`, `xCommentBoldItalic` accurately.
    # For  example, this  region is  not accurate enough  to describe  an italic
    # element:
    #
    #     syn region xCommentItalic start=/\*/ end=/\*/
    #
    # A text in bold wrongly matches this description.
    # This would be more accurate:
    #
    #     syn region xCommentItalic start=/\*\@1<!\*\*\@!/ end=/\*\@1<!\*\*\@!/
    #
    # But it would probably have an impact on Vim's performance.
    #}}}
    SynItalic(ft, commentGroup)
    SynBold(ft, commentGroup)
    SynBolditalic(ft, commentGroup)
    # TODO: This invocation of `SynOption()` doesn't require several arguments.
    # This  is neat;  study how  it's possible,  and try  to redefine  the other
    # syntax groups, so that we have less arguments to pass.
    SynOption(ft)
    SynUrl(ft, commentGroup)
    SynFoldmarkers(ft, cml_0_1, commentGroup)

    FixCommentRegion(ft)
    FixAllbut(ft)

    HighlightGroupsLinks(ft)
    # TODO: Read: https://daringfireball.net/projects/markdown/syntax{{{
    # and   https://daringfireball.net/projects/markdown/basics
    #
    # `markdown` provides some useful syntax which our comments
    # don't emulate yet.
    #
    # Like the fact that  a list item can include a blockquote  or a code block.
    # Make some tests on github,  stackexchange, reddit, and with `:Preview`, to
    # see what the current syntax is (markdown has evolved I guess...).
    #
    # And try to emulate every interesting syntax you find.
    #}}}
enddef

def FixAllbut(ft: string) #{{{2
    # What's the purpose of this function?{{{
    #
    # Some default syntax plugins define groups with the argument `contains=ALLBUT`.
    # It means that they can contain *anything* except a few specific groups.
    # Because of this, they can contain our custom groups.
    # And as a result, our code may be applied wrong graphical attributes:
    #
    #     $ cat <<'EOF' >/tmp/lua.lua
    #     ( 1 * 2 * 3 )
    #     EOF
    #
    #     $ vim /tmp/lua.lua
    #
    # We need  an easy  way to tell  Vim that these  default groups  must *also*
    # exclude our custom groups.
    #
    # ---
    #
    # Relevant issue: https://github.com/vim/vim/issues/1265
    #}}}

    # What does this do?{{{
    #
    # It defines  a cluster  containing all  the custom  syntax groups  that the
    # current plugin defines.
    #}}}
    var groups = mapnew(CUSTOM_GROUPS,
            {_, v -> v[0] == '@' ? '@' .. ft .. trim(v, '@') : ft .. v})
        ->join(',')
    exe 'syn cluster ' .. ft .. 'MyCustomGroups contains=' .. groups

    # get the list of groups using `ALLBUT`, and save it in a script-local variable
    # to avoid having to recompute it every time we reload the same kind of buffer
    if !has_key(allbut_groups, ft)
        # Don't try to read and parse the original syntax plugin.{{{
        #
        # `ALLBUT` could be  on a continuation line, and in  this case, it would
        # be hard to get the name of the syntax group.
        #}}}
        allbut_groups[ft] = execute('syn list')
            ->split('\n')
            ->filter({_, v -> v =~ '\m\CALLBUT' && v !~ '^\s'})
            ->map({_, v -> matchstr(v, '\S\+')})
        # Ignore groups defined for embedding another language.{{{
        #
        # Otherwise, this  function breaks the  syntax highlighting in  some Vim
        # files, when we embed the code of another language.
        #
        # For example in `$VIMRUNTIME/autoload/rubycomplete.vim`.
        # Move at the end, and press `=d` to redraw/reload the syntax plugin.
        #
        # The issue is not in the syntax  of the `:syn` commands executed at the
        # end of the function.
        # Maybe they're executed too soon, or too late, I don't know.
        #
        # If you duplicate the ruby syntax plugin in `~/.vim/syntax/ruby.vim`,
        # and if you edit `$VIMRUNTIME/syntax/vim.vim:689`:
        #
        #     " this line makes Vim source the default ruby syntax plugin
        #     " when defining the cluster/region used to embed ruby inside Vim
        #     s:rubypath= fnameescape(expand("<sfile>:p:h")."/ruby.vim")
        #
        #     " this new line makes Vim source our custom ruby syntax plugin instead
        #     s:rubypath= split(globpath(&rtp,"syntax/ruby.vim"),"\n")[0]
        #
        # Then, if you  edit all the items  using `ALLBUT` so that  they also ignore
        # `@xMyCustomGroups`, then the issue disappears.
        # And yet, the definition of the items is the same as in this function.
        # So, again, the issue is *not* in the syntax of the command.
        #
        # ---
        #
        # Note that Vim doesn't need  this function, because there's no `ALLBUT`
        # in its syntax plugin.
        #
        # Besides, Vim is  a special case, because I doubt  there are many languages
        # where the default syntax plugin supports embedding other languages.
        # For example, these languages do not support it:
        # awk, conf, css, desktop, dircolors, gitconfig, lua, python, readline, sed,
        # snippets, tmux, xdefaults, xkb, zsh...
        #
        # To check this yourself, search for `syn\%[tax]\s*include`.
        #
        # OTOH, another language may be embedded in C and html.
        # But  I don't  think  they  will cause  an  issue,  because there's  no
        # `ALLBUT` in the html syntax plugin.
        # And the embedding in C seems very limited/simple.
        # It defines the cluster `@cAutodoc` which contains all the items in:
        #
        #     /usr/local/share/vim/vim81/syntax/autodoc.vim
        #
        # But none of them contains `ALLBUT`.
        #
        # ---
        #
        # If you  need to ignore  another filetype, but  you can't because  it would
        # break  sth else,  consider  maintaining  your own  version  of the  syntax
        # plugin, in which you ignore `@xMyCustomGroups` whenever it's necessary.
        #}}}
        filter(allbut_groups[ft], {_, v -> v =~ '^' .. ft})
    endif

    for group in allbut_groups[ft]
        var cmds = GetCmdsToResetGroup(group)

        # add `@xMyCustomGroups` after `ALLBUT`
        map(cmds, {_, v -> substitute(v, '\m\CALLBUT,', 'ALLBUT,@' .. ft .. 'MyCustomGroups,', '')})

        # clear and redefine all the items in the group
        exe 'syn clear ' .. group
        map(cmds, {_, v -> execute(v)})
    endfor
enddef

def FixCommentRegion(ft: string) #{{{2
    # Sometimes, a line is wrongly highlighted as a comment. {{{
    #
    # For  some filetypes,  if a  commented code  block precedes  an uncommented
    # line, the latter is wrongly highlighted as a comment.
    #
    # This is the case for css files.
    #
    # MWE:
    #
    #     $ cat <<'EOF' >/tmp/css.css
    #     /*     code block */
    #     body {
    #       background-color: lightblue;
    #     }
    #     EOF
    #
    #     :syn clear
    #     :syn region cssComment start='/\*' end='\*/'
    #     :syn region cssCommentCodeBlock matchgroup=Comment start=+\V\/*\m \{5,}+ end=/$/  contained oneline keepend containedin=cssComment
    #     :hi link cssComment Comment
    #
    # Explanation:
    # The codeblock  consumes the end  of the  `cssComment` region, which  makes the
    # latter continue on the next line(s), until it finds an – untouched – end.
    #
    # Solutions:
    #
    # Redefine the region with the `keepend` argument:
    #
    #     syn region cssComment start='/\*' end='\*/' keepend
    #
    # ---
    #
    # Or redefine the region as a match:
    #
    #     syn match cssComment '/\*\_.\{-}\*/'
    #
    # A match won't suffer from this  issue, because it doesn't have the concept
    # of an end; nothing can be inadvertently consumed.
    # So, even though it's true that a  contained item *can* cause a match to be
    # extended, it can only do so if it goes *beyond* the containing match.
    # Here, that's not going to happen; our contained styles never go beyond the
    # last character of a comment.
    #}}}
    var cmds = GetCmdsToResetGroup(ft .. 'Comment')
    # Do not reset the comment group if it doesn't contain any region item.{{{
    #
    # It's only needed for a region, not for a match.
    # Otherwise, you will break the highlighting  of a list item; only the first
    # line will be correctly highlighted, the next ones will be highlighted as a
    # codeblock.
    #
    # ---
    #
    # In  a Vim  file, it  would also cause  `"string"` to  be highlighted  as a
    # comment in:
    #
    #     fu Func() abort
    #         return "string"
    #     endfu
    #
    # While it should be highlighted as a string.
    #}}}
    if match(cmds, '^syn\%[tax]\s\+region') == -1
        return
    endif
    # FIXME: This might break the highlighting of a list item.{{{
    #
    # The lines after the first one will be highlighted as a codeblock.
    #
    # If that  happens, try to  redefine it  as a match,  so that we  don't need
    # keepend, and we don't need to reset the group.
    #
    # If it gets too complex, get rid of this function, and redefine the comment
    # group in `~/.vim/after/syntax/x.vim` on a per-filetype basis.
    #}}}
    map(cmds, {_, v -> v .. ' keepend'})
    exe 'syn clear ' .. ft .. 'Comment'
    map(cmds, {_, v -> execute(v)})
enddef

def GetCmdsToResetGroup(group: string): list<string> #{{{2
    # get original definition
    var definition = execute('syn list ' .. group)->split('\n')

    # remove noise
    filter(definition, {_, v -> v !~ '^---\|^\s\+links\s\+to\s\+'})
    if empty(definition)
        return []
    endif
    definition[0] = substitute(definition[0], '^\a\+\s\+xxx', '', '')

    # add  `:syn [keyword|match|region]` to  build new commands  to redefine
    # the items in the group
    var cmds = map(definition, {_, v ->
        match(v, '\m\C\<start=') >= 0
        ?     'syn region ' .. group .. ' ' .. v
        : match(v, '\m\C\<match\>') >= 0
        ?     'syn match ' .. group .. ' ' .. substitute(v, 'match', '', '')
        :     'syn keyword ' .. group .. ' ' .. v
        })

    return cmds
enddef

def GetCommentgroup(ft: string): string #{{{2
    if ft == 'c'
        # What's the difference between `cComment` and `cCommentL`?{{{
        #
        # `cComment` = old comment style (`/* */`).
        # `cCommentL` = new comment style (`//`).
        #}}}
        # Which pitfall should I avoid if I try to add support for `cComment`?{{{
        #
        # Disable the italic style in the old comment style.
        #
        # You won't be able to use `_` to highlight text in italic, because existing
        # comments often  contain variable  names with  underscores; and  since they
        # aren't  inside  backticks,  part  of  the variable  name  is  wrong  (some
        # underscores are concealed, and the name is partially in italic).
        #
        # So, you'll have to use `*`.
        # But this  will create other  issues, which are  due to the  comment leader
        # also using `*`.
        # Sometimes, some text will  be in italic while it shouldn't,  and a line of
        # code after a comment will be wrongly highlighted as a comment.
        #
        # You can reduce the frequency of the issues by adding more and more lookarounds.
        #
        # Start of region:
        #     *
        #     *\S
        #     /\@1<!*\S
        #
        # End of region:
        #     *
        #     \S*
        #     \S*/\@!
        #
        # But  no matter  what  you do,  there'll  always be  some  cases where  the
        # highlighting is wrong.
        #}}}
        return 'cCommentL'
    elseif ft == 'html'
        # `htmlCommentPart` is required; not sure about `htmlComment`...
        return 'htmlComment,htmlCommentPart'
    elseif ft == 'vim'
        return 'vimComment,vim9Comment,vimLineComment,vim9LineComment'
    elseif ft == 'sh'
        return 'shComment,shQuickComment'
    else
        return ft .. 'Comment'
    endif
enddef

def GetFiletype(): string #{{{2
    var ft = expand('<amatch>')
    if ft == 'snippets'
        ft = 'snip'
    elseif ft == 'desktop'
        ft = 'dt'
    elseif ft == 'systemd'
        ft = 'dosini'
    endif
    return ft
enddef

def HighlightGroupsLinks(ft: string) #{{{2
    exe 'hi ' .. ft .. 'FoldMarkers term=bold cterm=bold gui=bold'

    exe 'hi link ' .. ft .. 'CommentURL CommentUnderlined'

    exe 'hi link ' .. ft .. 'CommentBold                  CommentBold'
    exe 'hi link ' .. ft .. 'CommentBoldItalic            CommentBoldItalic'
    exe 'hi link ' .. ft .. 'CommentCodeBlock             CommentCodeSpan'
    exe 'hi link ' .. ft .. 'CommentCodeSpan              CommentCodeSpan'
    exe 'hi link ' .. ft .. 'CommentItalic                CommentItalic'

    exe 'hi link ' .. ft .. 'CommentBlockquote            markdownBlockquote'
    exe 'hi link ' .. ft .. 'CommentBlockquoteBold        markdownBlockquoteBold'
    exe 'hi link ' .. ft .. 'CommentBlockquoteBoldItalic  markdownBlockquoteBoldItalic'
    exe 'hi link ' .. ft .. 'CommentBlockquoteCodeSpan    markdownBlockquoteCodeSpan'
    exe 'hi link ' .. ft .. 'CommentBlockquoteItalic      markdownBlockquoteItalic'

    exe 'hi link ' .. ft .. 'CommentKey                   markdownKey'
    exe 'hi link ' .. ft .. 'CommentLeader                Comment'
    exe 'hi link ' .. ft .. 'CommentListItem              markdownListItem'
    exe 'hi link ' .. ft .. 'CommentListItemBlockquote    markdownListItemBlockquote'
    exe 'hi link ' .. ft .. 'CommentListItemBold          markdownListItemBold'
    exe 'hi link ' .. ft .. 'CommentListItemBoldItalic    markdownListItemBoldItalic'
    exe 'hi link ' .. ft .. 'CommentListItemCodeBlock     CommentCodeSpan'
    exe 'hi link ' .. ft .. 'CommentListItemCodeSpan      CommentListItemCodeSpan'
    exe 'hi link ' .. ft .. 'CommentListItemItalic        markdownListItemItalic'
    exe 'hi link ' .. ft .. 'CommentListItemOutput        CommentPreProc'
    exe 'hi link ' .. ft .. 'CommentOption                markdownOption'
    exe 'hi link ' .. ft .. 'CommentOutput                CommentPreProc'
    exe 'hi link ' .. ft .. 'CommentPointer               markdownPointer'
    exe 'hi link ' .. ft .. 'CommentRule                  markdownRule'
    exe 'hi link ' .. ft .. 'CommentTable                 markdownTable'
    exe 'hi link ' .. ft .. 'CommentTitle                 CommentPreProc'
enddef

def SynCommentleader(ft: string, cml: string) #{{{2
    # Why `\%(^\s*\)\@<=`?{{{
    #
    # Without it, if your comment leader appears inside a list item, it would be
    # highlighted as a comment leader, instead of being part of the item.
    #}}}
    exe 'syn match ' .. ft .. 'CommentLeader'
        .. ' /\%(^\s*\)\@<=' .. cml .. '/'
        .. ' contained'
enddef

def SynCommenttitle(ft: string, cml: string, nr: number) #{{{2
    # Why this guard?{{{
    #
    # The default Vim syntax plugin already installs this style.
    # And we can't install it for html, because it causes an issue:
    #
    #     <!-- Some Comment Title: -->
    #     <!-- some comment        -->
    #
    # Everything after  `:` is  highlighted according to  `htmlCommentError` (no
    # color), except the two parts of the comment leader.
    #}}}
    if index(['html', 'vim'], ft) >= 0
        return
    endif

    exe 'syn match ' .. ft .. 'CommentTitleLeader'
        .. ' /' .. cml .. '\s\+/ms=s+' .. nr
        .. ' contained'
    # Don't remove `containedin=`!{{{
    #
    # We need  it, for example,  to allow  `awkCommentTitle` to be  contained in
    # `awkComment`.  Same thing for many other filetypes.
    #}}}
    exe 'syn match ' .. ft .. 'CommentTitle'
        .. ' /' .. cml .. '\s*\u\w*\%(\s\+\u\w*\)*:/hs=s+' .. nr
        .. ' contained'
        .. ' containedin=' .. ft .. 'Comment' .. (ft == 'c' ? 'L' : '')
        .. ' contains=' .. ft .. 'CommentTitleLeader,'
        .. ft .. 'Todo'
enddef

def SynListItem(ft: string, cml: string, commentGroup: string) #{{{2
    exe 'syn cluster ' .. ft .. 'CommentListItemElements'
        .. ' contains=' .. ft .. 'CommentListItemItalic,'
                        .. ft .. 'CommentListItemBold,'
                        .. ft .. 'CommentListItemBoldItalic,'
                        .. ft .. 'CommentListItemCodeSpan,'
                        .. ft .. 'CommentListItemCodeBlock,'
                        .. ft .. 'CommentListItemOutput,'
                        .. '@Spell'

    # - some item 1
    #   some text
    #
    # - some item 2
    var list_marker = '[-*+]'
    exe 'syn region ' .. ft .. 'CommentListItem'
        .. ' start=/\%(^\s*\)\@<=' .. cml .. ' \{,4\}\%(' .. list_marker .. '\|\d\+\.\)\s\+\S/'
        # an empty line (except for the comment leader), followed by a non-empty line
        .. ' end=/' .. cml .. '\ze\s*\n\s*' .. cml .. ' \{,4}\S'
        # the end/beginning of a fold right after the end of the list (no empty line in between)
        .. '\|\n\ze\s*' .. cml .. '.*\%(}' .. '}}\|{' .. '{{\)'
        # a non-commented line
        .. '\|^\%(\s*' .. cml .. '\)\@!/'
        .. ' keepend'
        .. ' contains=' .. ft .. 'FoldMarkers,'
                        .. ft .. 'CommentLeader,'
                 .. '@' .. ft .. 'CommentListItemElements'
        .. ' contained'
        .. ' containedin=' .. commentGroup
enddef

def SynCodeBlock(ft: string, cml: string, commentGroup: string) #{{{2
    # Why a region?{{{
    #
    # I  want `xCommentCodeBlock`  to highlight  only  after 5  spaces from  the
    # comment leader (instead of complete lines).
    # It's less noisy.
    #}}}
    # Why `^\s*` in the `start` argument?{{{
    #
    # Without  it, `,  and something  else` would  be wrongly  highlighted as  a
    # codeblock on the second line:
    #
    # some long text common to both lines, and something unique
    # "                                  , and something else
    #}}}
    # Why inside a lookbehind?{{{
    #
    # Without `\@<=`, `^\s*` would break a codeblock in a shell function.
    #}}}
    exe 'syn region ' .. ft .. 'CommentCodeBlock'
        .. ' matchgroup=Comment'
        .. ' start=/\%(^\s*\)\@<=' .. cml .. '\\\= \{5,}/'
        .. ' end=/$/'
        .. ' keepend'
        .. ' contained'
        .. ' containedin=' .. commentGroup
        .. ' oneline'

    # - some item
    #
    #         some code block
    #
    # - some item
    exe 'syn region ' .. ft .. 'CommentListItemCodeBlock'
        .. ' matchgroup=Comment'
        .. ' start=/\%(^\s*\)\@<=' .. cml .. ' \{9,}/'
        .. ' end=/$/'
        .. ' keepend'
        .. ' contained'
        .. ' containedin=' .. ft .. 'CommentListItem'
        .. ' oneline'
enddef

def SynCodeSpan(ft: string, commentGroup: string) #{{{2
    # TODO: We sometimes have comments with a different syntax for codespans:{{{
    #
    #     `some text'
    #
    # Example:
    #
    #     ~/Vcs/zsh/Misc/vcs_info-examples
    #
    # Try to support them.  Also in markdown  notes when we copy paste some text
    # from a man page.
    #}}}

    # What does `matchroup` do?{{{
    #
    # From `:h :syn-matchgroup`:
    #
    #    > "matchgroup" can  be used to  highlight the start and/or  end pattern
    #    > differently than the body of the region.
    #}}}
    # Why do you need it here?{{{
    #
    # Without it, the surrounding markers are not concealed.
    # From `:h :syn-concealends`:
    #
    #    > The ends  of a region  can only be  concealed separately in  this way
    #    > when they have their own highlighting via "matchgroup"
    #}}}
    # Is the `contained` argument necessary for all syntax items?{{{
    #
    # Probably not, but better be safe than sorry.
    #
    # You must use `contained` when the item may match at the top level, and you
    # don't want to.
    #
    # It's definitely necessary for:
    #
    #     CommentCodeSpan
    #     CommentItalic
    #     CommentBold
    #
    # Otherwise, your code may be applied wrong graphical attributes:
    #
    #     $ cat <<'EOF' >/tmp/awk.awk
    #     * word *
    #     ` word `
    #     ** word **
    #     EOF
    #
    #     $ vim !$
    #}}}
    # some `code span` in a comment
    exe 'syn region ' .. ft .. 'CommentCodeSpan'
        .. ' matchgroup=Comment'
        .. ' start=/\z(`\+\)/'
        .. ' end=/\z1/'
        .. ' keepend'
        .. ' concealends'
        .. ' contained'
        .. ' containedin=' .. commentGroup
        .. ' oneline'

    # - some `code span` item
    exe 'syn region ' .. ft .. 'CommentListItemCodeSpan'
        .. ' matchgroup=markdownListItem'
        .. ' start=/\z(`\+\)/'
        .. ' end=/\z1/'
        .. ' keepend'
        .. ' concealends'
        .. ' contained'
        .. ' oneline'

    # > some `code span` in a quote
    exe 'syn region ' .. ft .. 'CommentBlockquoteCodeSpan'
        .. ' matchgroup=markdownBlockquote'
        .. ' start=/\z(`\+\)/'
        .. ' end=/\z1/'
        .. ' keepend'
        .. ' concealends'
        .. ' contained'
        .. ' containedin=' .. ft .. 'CommentBlockquote'
        .. ' oneline'
enddef

def SynItalic(ft: string, commentGroup: string) #{{{2
    # It's impossible  to reliably  support the  italic style  in a  css buffer,
    # because the comment leader includes a star.
    # See our comments about the pitfall to avoid when trying to add support for
    # `cComment`.
    if ft == 'css'
        return
    endif

    # some *italic* comment
    exe 'syn region ' .. ft .. 'CommentItalic'
        .. ' matchgroup=Comment'
        .. ' start=/\*/'
        .. ' end=/\*/'
        .. ' keepend'
        .. ' concealends'
        .. ' contained'
        .. ' containedin=' .. commentGroup
        .. ' contains=@Spell'
        .. ' oneline'

    # - some *italic* item
    exe 'syn region ' .. ft .. 'CommentListItemItalic'
        .. ' matchgroup=markdownListItem'
        .. ' start=/\*/'
        .. ' end=/\*/'
        .. ' keepend'
        .. ' concealends'
        .. ' contained'
        .. ' contains=@Spell'
        .. ' oneline'

    # > some *italic* quote
    exe 'syn region ' .. ft .. 'CommentBlockquoteItalic'
        .. ' matchgroup=markdownBlockquote'
        .. ' start=/\*/'
        .. ' end=/\*/'
        .. ' keepend'
        .. ' concealends'
        .. ' contained'
        .. ' containedin=' .. ft .. 'CommentBlockquote'
        .. ' contains=@Spell'
        .. ' oneline'
enddef

def SynBold(ft: string, commentGroup: string) #{{{2
    # some **bold** comment
    exe 'syn region ' .. ft .. 'CommentBold'
        .. ' matchgroup=Comment'
        .. ' start=/\*\*/'
        .. ' end=/\*\*/'
        .. ' keepend'
        .. ' concealends'
        .. ' contained'
        .. ' containedin=' .. commentGroup
        .. ' contains=@Spell'
        .. ' oneline'

    # - some **bold** item
    exe 'syn region ' .. ft .. 'CommentListItemBold'
        .. ' matchgroup=markdownListItem'
        .. ' start=/\*\*/'
        .. ' end=/\*\*/'
        .. ' keepend'
        .. ' concealends'
        .. ' contained'
        .. ' contains=@Spell'
        .. ' oneline'

    # > some **bold** quote
    exe 'syn region ' .. ft .. 'CommentBlockquoteBold'
        .. ' matchgroup=markdownBlockquote'
        .. ' start=/\*\*/'
        .. ' end=/\*\*/'
        .. ' keepend'
        .. ' concealends'
        .. ' contained'
        .. ' containedin=' .. ft .. 'CommentBlockquote'
        .. ' contains=@Spell'
        .. ' oneline'
enddef

def SynBolditalic(ft: string, commentGroup: string) #{{{2
    # some ***bold and italic*** comment
    exe 'syn region ' .. ft .. 'CommentBoldItalic'
        .. ' matchgroup=Comment'
        .. ' start=/\*\*\*/'
        .. ' end=/\*\*\*/'
        .. ' keepend'
        .. ' concealends'
        .. ' contained'
        .. ' containedin=' .. commentGroup
        .. ' contains=@Spell'
        .. ' oneline'

    # - some ***bold and italic*** item
    exe 'syn region ' .. ft .. 'CommentListItemBoldItalic'
        .. ' matchgroup=markdownListItem'
        .. ' start=/\*\*\*/'
        .. ' end=/\*\*\*/'
        .. ' keepend'
        .. ' concealends'
        .. ' contained'
        .. ' contains=@Spell'
        .. ' oneline'

    # > some ***bold and italic*** quote
    exe 'syn region ' .. ft .. 'CommentBlockquoteBoldItalic'
        .. ' matchgroup=markdownBlockquote'
        .. ' start=/\*\*\*/'
        .. ' end=/\*\*\*/'
        .. ' keepend'
        .. ' concealends'
        .. ' contained'
        .. ' containedin=' .. ft .. 'CommentBlockquote'
        .. ' contains=@Spell'
        .. ' oneline'
enddef

def SynBlockquote(ft: string, cml: string, commentGroup: string) #{{{2
    # > some quote
    # <not> a quote
    # Why do you allow `xCommentBold` to be contained in `xCommentBlockquote`?{{{
    #
    # In a  markdown buffer,  we can make  some text be  displayed in  bold even
    # inside a blockquote.
    # To stay  consistent, we should be able  to do the same in  the comments of
    # other filetypes.
    #}}}
    exe 'syn match ' .. ft .. 'CommentBlockquote'
        .. ' /' .. cml .. '\\\= \{,4}>.*/'
        .. ' contained'
        .. ' containedin=' .. commentGroup
        .. ' contains=' .. ft .. 'CommentLeader,'
                        .. ft .. 'CommentBold,'
                        .. ft .. 'CommentBlockquoteConceal,'
                        .. '@Spell'
        .. ' oneline'

    exe 'syn match ' .. ft .. 'CommentBlockquoteConceal'
        .. ' /\%(' .. cml .. '\\\= \{,4}\)\@<=>\s\=/'
        .. ' contained'
        .. ' conceal'

    # -   some list item
    #
    #     > some quote
    #
    # -   some list item
    exe 'syn match ' .. ft .. 'CommentListItemBlockquote'
        .. ' /' .. cml .. ' \{5}>.*/'
        .. ' contained'
        .. ' containedin=' .. ft .. 'CommentListItem'
        .. ' contains=' .. ft .. 'CommentLeader,'
                        .. ft .. 'CommentBlockquoteBold,'
                        .. ft .. 'CommentListItemBlockquoteConceal,'
                        .. '@Spell'
        .. ' oneline'

    exe 'syn match ' .. ft .. 'CommentListItemBlockquoteConceal'
        .. ' /\%(' .. cml .. ' \{5}\)\@<=>\s\=/'
        .. ' contained'
        .. ' conceal'
enddef

def SynOutput(ft: string, cml: string) #{{{2
    #     $ shell command
    #     output~
    # Why `\%(...\)\@<=` for these 2 statements?{{{
    #
    # It's required in the first statement because:
    #
    #    1. `xCommentOutput` is contained in `xCommentCodeBlock`
    #
    #    2. `xCommentCodeBlock` is a region using `matchgroup=`
    #
    #    3. `matchgroup=` prevents  a contained  item to  match where  `start` and
    #       `end` matched
    #
    # It's required in  the second statement because we don't  want to highlight
    # with `Ignore` *all* the output of a command, only the last tilde.
    #}}}
    exe 'syn match ' .. ft .. 'CommentOutput'
        .. ' /\%(^\s*' .. cml .. ' \{5,}\)\@<=.*\~$/'
        .. ' contained'
        .. ' containedin=' .. ft .. 'CommentCodeBlock'
        .. ' nextgroup=' .. ft .. 'CommentIgnore'

    exe 'syn match ' .. ft .. 'CommentIgnore'
        .. ' /\%(^\s*' .. cml .. '.*\)\@<=.$/'
        .. ' contained'
        .. ' containedin=' .. ft .. 'CommentOutput,' .. ft .. 'CommentListItemOutput'
        .. ' conceal'

    # - some item
    #         some output~
    exe 'syn match ' .. ft .. 'CommentListItemOutput'
        .. ' /\%(^\s*' .. cml .. ' \{9,}\)\@<=.*\~$/'
        .. ' contained'
        .. ' containedin=' .. ft .. 'CommentListItemCodeBlock'
        .. ' nextgroup=' .. ft .. 'CommentIgnore'
enddef

def SynOption(ft: string) #{{{2
    # some `'option'`
    # - some `'option'`
    exe 'syn match ' .. ft .. 'CommentOption'
        .. ' /`\@1<=''[a-z]\{2,}''\ze`/'
        .. ' contained'
        .. ' containedin=' .. ft .. 'CommentCodeSpan,' .. ft .. 'CommentListItemCodeSpan'
enddef

def SynPointer(ft: string, cml: string, commentGroup: string) #{{{2
    # not a pointer v
    # v
    #       ^
    # ^---^
    # v---v
    #     "   ^---^
    exe 'syn match ' .. ft .. 'CommentPointer'
        .. ' /' .. cml .. '\s*\%(' .. cml .. '\)\=\s*\%([v^✘✔-]\+\s*\)\+$/'
        .. ' contains=' .. ft .. 'CommentLeader'
        .. ' contained'
        .. ' containedin=' .. commentGroup
enddef

def SynRule(ft: string, cml: string, commentGroup: string) #{{{2
    # some
    # ---
    # rule
    # Where does the regex come from?{{{
    #
    # Tpope uses a similar regex in his markdown syntax plugin:
    #
    #     - *- *-[ -]*$
    #
    # We  just add  ` *`  in front  of it,  because there  could be  some spaces
    # between the comment leader and a horizontal rule.
    #}}}
    exe 'syn match ' .. ft .. 'CommentRule'
        .. ' /' .. cml .. ' *- *- *-[ -]*$/'
        .. ' contained'
        .. ' containedin=' .. commentGroup
        .. ' contains=' .. ft .. 'CommentLeader'
enddef

def SynTable(ft: string, cml: string, commentGroup: string) #{{{2
    # some table:
    #
    #    ┌───────┬──────┐
    #    │  one  │ two  │
    #    ├───────┼──────┤
    #    │ three │ four │
    #    └───────┴──────┘

    # Note that the table must begin 4 spaces after the comment leader (instead of 5 for a code block).
    # If you tweak the regex here, try to do the same in our markdown syntax plugin.{{{
    #
    # More specifically, check out the definition of the syntax group `markdownTable`.
    #
    # ---
    #
    # Also, check out all the examples of tables given in the example right above.
    # Make sure they're still correctly highlighted in a Vim comment.
    #}}}
    # Why not using a tab character to distinguish between a code block and a table?{{{
    #
    # A tab character means that the distance between the comment leader and the
    # beginning  of the  table would  vary, depending  on the  current level  of
    # indentation of the comment.
    #
    # It's distracting, especially when you increase/decrease the indentation of
    # a comment.
    #}}}
    # Why don't you allow a code span to be contained in a table?{{{
    #
    # The concealing of the backticks would break the alignment of the table.
    # Although, I  guess you could  include a  code span without  concealing the
    # backticks, but you would need to define another code span syntax item.
    #}}}
    exe 'syn region ' .. ft .. 'CommentTable'
        .. ' matchgroup=Comment'
        .. ' start=/' .. cml .. ' \{4,}\ze\%(┌[─┬┼]\+[┤┐]\|└[─┴]\+┘\|│.*[^ \t│].*│\|├─.*┤\|│.*├.*┤\)/'
        .. ' end=/$/'
        .. ' keepend'
        .. ' oneline'
        .. ' contained'
        .. ' containedin=' .. commentGroup
        .. ' contains=@Spell'
enddef

def SynUrl(ft: string, commentGroup: string) #{{{2
    # Where does the regex come from?{{{
    #
    # https://github.com/tmux-plugins/vim-tmux/blob/4e77341a2f8b9b7e41e81e9debbcecaea5987c85/syntax/tmux.vim#L161
    #}}}
    # TODO: Consider simplifying the regex. {{{
    #
    # And/or maybe leverage the regex used in the default markdown syntax plugin.
    #
    #     markdownLinkText xxx matchgroup=markdownLinkTextDelimiter
    #                          start=/!\=\[\%(\_[^]]*]\%(\s\=[[(]\)\)\@=/
    #                          end=/\]\%(\s\=[[(]\)\@=/
    #                          concealends
    #                          contains=@markdownInline,markdownLineStart
    #                          nextgroup=markdownLink,markdownId
    #                          skipwhite
    #     links to Conditional
    #
    #     markdownUrl    xxx match /\S\+/
    #                        contained nextgroup=markdownUrlTitle
    #                        skipwhite
    #                        matchgroup=markdownUrlDelimiter
    #                        start=/</
    #                        end=/>/
    #                        contained
    #                        oneline
    #                        keepend
    #                        nextgroup=markdownUrlTitle
    #                        skipwhite
    #     links to Float
    #}}}
    exe 'syn match ' .. ft
        .. 'CommentURL `\v<(((https=|ftp)://|file:)[^''  <>"]+|(www|web|w3)[a-z0-9_-]*\.[a-z0-9._-]+\.[^''  <>"]+)[a-zA-Z0-9/]`'
        .. ' contained'
        .. ' containedin=' .. commentGroup
enddef

def SynFoldmarkers(ft: string, cml_0_1: string, commentGroup: string) #{{{2
    # If you don't care about html and css, you could probably simplify the code
    # of this function, and get rid of `cml_right`.

    # replace noisy markers, used in folds, with ❭ and ❬
    # Why not `containedin=ALL`?{{{
    #
    # Run:
    #
    #     :setl cole=2
    #
    # Result:
    #
    # If your fold  markers are prefixed by `n` whitespaces,  you will see `n+1`
    # conceal characters instead of just 1.
    #
    # For example:
    #
    #     SPC SPC { { {
    #
    # `SPC SPC { { {` will  be matched by the  regex `\s*{{ {`, and  so will be
    # concealed by the `❭` character.
    # But `SPC { { {` will also  be matched by  the regex,  and `xFoldMarkers`
    # *can* be contained in itself (at a later position), so it will *also* be
    # concealed by the `❭` character.
    # Same thing for `{ { {` (without space).
    #
    # In the end, you will have 3 conceal characters, instead of 1.
    #}}}
    # The conceal markers are barely readable!{{{
    #
    # Try more thick ones:
    #
    #    ❭❬
    #    ❯❮
    #    ❱❰
    #}}}
    var cml_left = matchstr(&l:cms, '\S*\ze\s*%s')->escape('\/')
    var cml_right = matchstr(&l:cms, '.*%s\s*\zs.*')->escape('\/')
    var pat: string
    var contained: string
    if cml_right == ''
        pat = cml_0_1 .. '\s*\%({' .. '{{\|}' .. '}}\)\d*\s*\ze\n'
        contained = ' contained'
    else
        pat = '\s*\V' .. cml_left .. '\m\s*\%({' .. '{{\|}' .. '}}\)\d*\s*\V' .. cml_right .. '\m\s*$'
        contained = ''
    endif
    exe 'syn match ' .. ft .. 'FoldMarkers'
        .. ' /' .. pat .. '/'
        .. ' conceal'
        .. ' cchar=❭'
        .. ' contains=' .. ft .. 'CommentLeader'
        .. contained
        .. ' containedin=' .. commentGroup
                    .. ',' .. ft .. 'CommentCodeBlock'
enddef

