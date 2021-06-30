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

const BLACKLIST: list<string> =<< trim END
    css
    html
END

var allbut_groups: dict<list<string>>

const CUSTOM_GROUPS: list<string> =<< trim END
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
    var filetype: string = expand('<amatch>')
    # Do *not* remove this function call.{{{
    #
    # Yes, it  seems redundant,  because it  will be called  a second  time when
    # `BufWinEnter` will be fired right after `FileType`.
    #
    # But if you don't set the options now, it may lead to subtle issues; we had
    # one in the past in `vim-fold` when we used a timer to delay `&l:foldmethod = 'manual'`.
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
    #         autocmd! * <buffer>
    #         autocmd BufWinEnter " do sth
    #     augroup END
    #
    # It will be removed by the `autocmd! * <buffer>` from the next autocmd.
    #
    # Indeed, in your vimrc, you have run `:filetype plugin on`.
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
    execute 'augroup MyFold_' .. filetype
        autocmd! * <buffer>
        # Why `FileChangedShellPost`?{{{
        #
        # Without, the folding would be lost when:
        #
        #    - we write a file owned by root with `:W`
        #    - we stash some changes with `$ git stash`
        #}}}
        autocmd BufWinEnter,FileChangedShellPost <buffer> FoldSettings()
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
    #     $ vim -Nu NONE -i NONE -es -S <(cat <<'EOF'
    #         vim9script
    #         autocmd QuickFixCmdPost * autocmd BufWinEnter * ++once lwindow
    #         autocmd FileType help autocmd BufWinEnter <buffer> &l:foldmethod = 'marker'
    #         lhelpgrep foobar
    #         getloclist(0, {winid: 0}).winid->win_gotoid()
    #         &verbose = 1 | echo &l:foldmethod
    #         quitall!
    #     EOF
    #     )
    #     marker˜
    #     " it should be "manual"
    #
    # Obviously,  if `'foldmethod'`  is wrongly  set to  "marker", and  the text
    # field of some entry contains a fold marker, the qf buffer gets folded.
    # This  can  have another  unexpected  side effect;  there  may be  a  weird
    # interaction with `vim-window` which makes the current line in the location
    # window wrong after `:llast`.
    #
    # ---
    #
    # The issue disappears if you remove the `BufWinEnter` autocmd:
    #
    #     autocmd FileType help autocmd BufWinEnter <buffer> &l:foldmethod = 'marker'
    #     →
    #     autocmd FileType help &l:foldmethod = 'marker'
    #
    # ---
    #
    # I can't find anything wrong in our original code (without the guard).
    # I think the issue is due to some special code related to `:lhelpgrep`.
    #
    # ---
    #
    # If you have other similar issues in the future, try this refactoring:
    #
    #     FoldSettings()
    #     →
    #     FoldSettings(filetype)
    #                  ^------^
    #
    #     autocmd BufWinEnter,FileChangedShellPost <buffer> FoldSettings()
    #     →
    #     execute 'autocmd BufWinEnter,FileChangedShellPost <buffer> FoldSettings(' .. string(filetype) .. ')'
    #     ^-------^                                                               ^--------------------------^
    #
    #     function FoldSettings() abort
    #     →
    #     function FoldSettings(filetype) abort
    #                           ^------^
    #
    #     if &filetype == 'qf'
    #         return
    #     endif
    #     →
    #        v-------------------v
    #     if &filetype != filetype
    #         return
    #     endif
    #}}}
    if &filetype == 'qf'
        return
    endif

    &l:foldmethod = 'marker'
    &l:foldtext = 'fold#foldtext#get()'
    &l:concealcursor = 'nc'
    &l:conceallevel = 3
enddef

export def UndoFtplugin() #{{{2
    var filetype: string = expand('<amatch>')
    b:undo_ftplugin = get(b:, 'undo_ftplugin', 'execute')
        .. ' | set concealcursor< conceallevel< foldmethod< foldtext<'
        .. ' | execute "autocmd! MyFold_' .. filetype .. ' * <buffer>"'
enddef
# }}}1
# syntax plugin {{{1
export def Syntax() #{{{2
    # We don't want to customize legacy Vim scripts.
    if get(b:, 'current_syntax', '') == 'vim'
    # NOTE: `b:current_syntax` might not exist.
    # For example, after `:syntax off` then `:syntax on`.
        return
    endif

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

    var filetype: string = GetFiletype()
    var cml: string = &l:commentstring->matchstr('\S*\ze\s*%s')
    var cml_0_1: string
    # What do you need this `nr` for?{{{
    #
    # For offsets when defining the syntax groups:
    #
    #    - xxxCommentTitle
    #    - xxxCommentTitleLeader
    #}}}
    #   Why capturing it now?{{{
    #
    # The next statement  invokes `escape()` which may  add backslashes, and
    # alter the real number of characters inside the comment leader.
    #}}}
    var nr: number = strcharlen(cml)
    # Why do you escape the slashes?{{{
    #
    # We use a slash as a delimiter around the patterns of our syntax elements.
    # As a result, if the comment  leader of the current filetype contains a
    # slash, we need to escape the  slashes to prevent Vim from interpreting
    # them as the end of the pattern.
    # This is needed for `xkb` where the comment leader is `//`.
    #}}}
    cml = escape(cml, '\/')
    cml_0_1 = '\V' .. '\%(' .. cml .. '\)\=' .. '\m'
    cml = '\V' .. cml .. '\m'
    var commentGroup: string = GetCommentgroup(filetype)

    SynCommentleader(filetype, cml)
    SynCommenttitle(filetype, cml, nr)
    # Why this guard? {{{
    #
    # For some filetypes, such as html  and css, it's too difficult to implement
    # some styles without any undesirable side effects.
    # }}}
    if index(BLACKLIST, filetype) == -1
        SynListItem(filetype, cml, commentGroup)
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
        SynCodeBlock(filetype, cml, commentGroup)
        SynBlockquote(filetype, cml, commentGroup)
        SynTable(filetype, cml, commentGroup)
        SynOutput(filetype)
        SynRule(filetype, cml, commentGroup)
        SynPointer(filetype, cml, commentGroup)
    endif
    SynCodeSpan(filetype, commentGroup)
    # Don't change the order of `SynItalic()`, `SynBold()` and `SynBolditalic()`!{{{
    #
    # It would break the syntax highlighting of some style (italic, bold, bold+italic).
    #
    # Indeed,   we  haven't   defined   the   syntax  groups   `xCommentItalic`,
    # `xCommentBold`, `xCommentBoldItalic` accurately.
    # For  example, this  region is  not accurate enough  to describe  an italic
    # element:
    #
    #     syntax region xCommentItalic start=/\*/ end=/\*/
    #
    # A text in bold wrongly matches this description.
    # This would be more accurate:
    #
    #     syntax region xCommentItalic start=/\*\@1<!\*\*\@!/ end=/\*\@1<!\*\*\@!/
    #
    # But it would probably have an impact on Vim's performance.
    #}}}
    SynItalic(filetype, commentGroup)
    SynBold(filetype, commentGroup)
    SynBolditalic(filetype, commentGroup)
    # TODO: This invocation of `SynOption()` doesn't require several arguments.
    # This  is neat;  study how  it's possible,  and try  to redefine  the other
    # syntax groups, so that we have less arguments to pass.
    SynOption(filetype)
    SynUrl(filetype, commentGroup)
    SynFoldmarkers(filetype, cml_0_1, commentGroup)

    FixCommentRegion(filetype)
    FixAllbut(filetype)

    HighlightGroupsLinks(filetype)
    # TODO: Read: https://daringfireball.net/projects/markdown/syntax{{{
    # and   https://daringfireball.net/projects/markdown/basics
    #
    # `markdown` provides  some useful syntax  which our comments  don't emulate
    # yet.
    #
    # Like the fact that  a list item can include a blockquote  or a code block.
    # Make some tests on github,  stackexchange, reddit, and with `:Preview`, to
    # see what the current syntax is (markdown has evolved I guess...).
    #
    # And try to emulate every interesting syntax you find.
    #}}}
enddef

def FixAllbut(filetype: string) #{{{2
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
    var groups: string = CUSTOM_GROUPS
        ->mapnew((_, v: string): string =>
                      v[0] == '@'
                    ?     '@' .. filetype .. v->trim('@')
                    :     filetype .. v
        )->join(',')
    execute 'syntax cluster ' .. filetype .. 'MyCustomGroups contains=' .. groups

    # get the list of groups using `ALLBUT`, and save it in a script-local variable
    # to avoid having to recompute it every time we reload the same kind of buffer
    if !allbut_groups->has_key(filetype)
        # Don't try to read and parse the original syntax plugin.{{{
        #
        # `ALLBUT` could be  on a continuation line, and in  this case, it would
        # be hard to get the name of the syntax group.
        #}}}
        allbut_groups[filetype] = execute('syntax list')
            ->split('\n')
            ->filter((_, v: string): bool => v =~ '\CALLBUT,' && v !~ '^\s')
            ->map((_, v: string): string => v->matchstr('\S\+'))
            # Ignore groups defined for embedding another language.{{{
            #
            # Otherwise, this  function breaks  the syntax highlighting  in some
            # Vim files, when we embed the code of another language.
            #
            # For example in `$VIMRUNTIME/autoload/rubycomplete.vim`.
            # Move at the end, and press `=d` to redraw/reload the syntax plugin.
            #
            # The issue is not in the  syntax of the `:syntax` commands executed
            # at the end of the function.
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
            # Then, if you  edit all the items using `ALLBUT`  so that they also
            # ignore `@xMyCustomGroups`, then the issue disappears.
            # And yet, the definition of the items is the same as in this function.
            # So, again, the issue is *not* in the syntax of the command.
            #
            # ---
            #
            # Note  that Vim  doesn't  need this  function,  because there's  no
            # `ALLBUT` in its syntax plugin.
            #
            # Besides, Vim  is a special  case, because  I doubt there  are many
            # languages where the default syntax plugin supports embedding other
            # languages.
            # For  example,  these  languages  do not  support  it:  awk,  conf,
            # css, desktop,  dircolors, gitconfig,  lua, python,  readline, sed,
            # snippets, tmux, xdefaults, xkb, zsh...
            #
            # To check this yourself, search for `syn\%[tax]\s*include`.
            #
            # OTOH, another language may be embedded in C and html.
            # But I  don't think they  will cause  an issue, because  there's no
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
            # If you need  to ignore another filetype, but you  can't because it
            # would break sth else, consider maintaining your own version of the
            # syntax  plugin, in  which you  ignore `@xMyCustomGroups`  whenever
            # it's necessary.
            #}}}
            ->filter((_, v: string): bool => v =~ '^' .. filetype)
    endif

    for group in allbut_groups[filetype]
        var cmds: list<string> = GetCmdsToResetGroup(group)
            # add `@xMyCustomGroups` after `ALLBUT`
            ->map((_, v: string): string =>
                    v->substitute('\CALLBUT,', 'ALLBUT,@' .. filetype .. 'MyCustomGroups,', ''))

        # clear and redefine all the items in the group
        execute 'syntax clear ' .. group
        cmds->map((_, v: string) => execute(v))
    endfor
enddef

def FixCommentRegion(filetype: string) #{{{2
    # No need in Vim9.  On the contrary, it would cause issues.
    if filetype == 'vim9'
        return
    endif
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
    #     :syntax clear
    #     :syntax region cssComment start='/\*' end='\*/'
    #     :syntax region cssCommentCodeBlock matchgroup=Comment start=+\V\/*\m \{5,}+ end=/$/  contained oneline keepend containedin=cssComment
    #     :highlight link cssComment Comment
    #
    # Explanation:
    # The codeblock  consumes the end  of the  `cssComment` region, which  makes the
    # latter continue on the next line(s), until it finds an – untouched – end.
    #
    # Solutions:
    #
    # Redefine the region with the `keepend` argument:
    #
    #     syntax region cssComment start='/\*' end='\*/' keepend
    #
    # ---
    #
    # Or redefine the region as a match:
    #
    #     syntax match cssComment '/\*\_.\{-}\*/'
    #
    # A match won't suffer from this  issue, because it doesn't have the concept
    # of an end; nothing can be inadvertently consumed.
    # So, even though it's true that a  contained item *can* cause a match to be
    # extended, it can only do so if it goes *beyond* the containing match.
    # Here, that's not going to happen; our contained styles never go beyond the
    # last character of a comment.
    #}}}
    var cmds: list<string> = GetCmdsToResetGroup(filetype .. 'Comment')
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
    #     function Func() abort
    #         return "string"
    #     endfunction
    #
    # While it should be highlighted as a string.
    #}}}
    if cmds->match('^syn\%[tax]\s\+region') == -1
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
    # FIXME: This might give higher priority to comment rules.{{{
    #
    # Because, in effect,  re-installing the rules now moves them  after all the
    # other ones.
    #
    # This can cause  other issues.  In particular, make sure  you don't have an
    # inline comment where there shouldn't be.
    #
    # I guess the right solution would be to send patches to the syntax authors.
    #}}}
    cmds->map((_, v: string): string => v .. ' keepend')
    execute 'syntax clear ' .. filetype .. 'Comment'
    cmds->map((_, v: string) => execute(v))
enddef

def GetCmdsToResetGroup(group: string): list<string> #{{{2
    # get original definition
    var definition: list<string> = execute('syntax list ' .. group)
        ->split('\n')
        # remove noise
        ->filter((_, v: string): bool => v !~ '^---\|^\s\+links\s\+to\s\+')
    if empty(definition)
        return []
    endif
    definition[0] = definition[0]->substitute('^\w\+\s\+xxx', '', '')

    # add `:syntax [keyword|match|region]` to build new commands to redefine the
    # items in the group
    var cmds: list<string> = definition
        ->map((_, v: string): string =>
                  match(v, '\C\<start=') >= 0
                ?     'syntax region ' .. group .. ' ' .. v
                : match(v, '\C\<match\>') >= 0
                ?     'syntax match ' .. group .. ' ' .. v->substitute('match', '', '')
                :     'syntax keyword ' .. group .. ' ' .. v
        )

    return cmds
enddef

def GetCommentgroup(filetype: string): string #{{{2
    if filetype == 'c'
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
    elseif filetype == 'html'
        # `htmlCommentPart` is required; not sure about `htmlComment`...
        return 'htmlComment,htmlCommentPart'
    elseif filetype == 'vim9'
        # Warning: Do not use a pattern!{{{
        #
        #     return 'vim9Comment.*'
        #                        ^^
        #                        ✘
        #
        # It would break the highlighting of pointers inside codeblock.
        # Because `vim9CommentPointer` would be contained in way too many groups.
        #}}}
        return 'vim9Comment,vim9CommentLine'
    elseif filetype == 'sh'
        return 'shComment,shQuickComment'
    else
        return filetype .. 'Comment'
    endif
enddef

def GetFiletype(): string #{{{2
    var filetype: string = expand('<amatch>')
    if filetype == 'vim' && b:current_syntax == 'vim9'
        filetype = 'vim9'
    elseif filetype == 'snippets'
        filetype = 'snip'
    elseif filetype == 'desktop'
        filetype = 'dt'
    elseif filetype == 'systemd'
        filetype = 'dosini'
    endif
    return filetype
enddef

def HighlightGroupsLinks(filetype: string) #{{{2
    execute 'highlight ' .. filetype .. 'FoldMarkers term=bold cterm=bold gui=bold'

    execute 'highlight def link ' .. filetype .. 'CommentURL CommentUnderlined'

    execute 'highlight def link ' .. filetype .. 'CommentBold                  CommentBold'
    execute 'highlight def link ' .. filetype .. 'CommentBoldItalic            CommentBoldItalic'
    execute 'highlight def link ' .. filetype .. 'CommentCodeBlock             CommentCodeSpan'
    execute 'highlight def link ' .. filetype .. 'CommentCodeSpan              CommentCodeSpan'
    execute 'highlight def link ' .. filetype .. 'CommentItalic                CommentItalic'

    execute 'highlight def link ' .. filetype .. 'CommentBlockquote            markdownBlockquote'
    execute 'highlight def link ' .. filetype .. 'CommentBlockquoteBold        markdownBlockquoteBold'
    execute 'highlight def link ' .. filetype .. 'CommentBlockquoteBoldItalic  markdownBlockquoteBoldItalic'
    execute 'highlight def link ' .. filetype .. 'CommentBlockquoteCodeSpan    markdownBlockquoteCodeSpan'
    execute 'highlight def link ' .. filetype .. 'CommentBlockquoteItalic      markdownBlockquoteItalic'

    execute 'highlight def link ' .. filetype .. 'CommentKey                   markdownKey'
    execute 'highlight def link ' .. filetype .. 'CommentLeader                Comment'
    execute 'highlight def link ' .. filetype .. 'CommentListItem              markdownListItem'
    execute 'highlight def link ' .. filetype .. 'CommentListItemBlockquote    markdownListItemBlockquote'
    execute 'highlight def link ' .. filetype .. 'CommentListItemBold          markdownListItemBold'
    execute 'highlight def link ' .. filetype .. 'CommentListItemBoldItalic    markdownListItemBoldItalic'
    execute 'highlight def link ' .. filetype .. 'CommentListItemCodeBlock     CommentCodeSpan'
    execute 'highlight def link ' .. filetype .. 'CommentListItemCodeSpan      CommentListItemCodeSpan'
    execute 'highlight def link ' .. filetype .. 'CommentListItemItalic        markdownListItemItalic'
    execute 'highlight def link ' .. filetype .. 'CommentListItemOutput        CommentPreProc'
    execute 'highlight def link ' .. filetype .. 'CommentOption                markdownOption'
    execute 'highlight def link ' .. filetype .. 'CommentOutput                CommentPreProc'
    execute 'highlight def link ' .. filetype .. 'CommentPointer               markdownPointer'
    execute 'highlight def link ' .. filetype .. 'CommentRule                  markdownRule'
    execute 'highlight def link ' .. filetype .. 'CommentTable                 markdownTable'
    execute 'highlight def link ' .. filetype .. 'CommentTitle                 CommentPreProc'
enddef

def SynCommentleader(filetype: string, cml: string) #{{{2
    # Why `\%(^\s*\)\@<=`?{{{
    #
    # Without it, if your comment leader appears inside a list item, it would be
    # highlighted as a comment leader, instead of being part of the item.
    #}}}
    execute 'syntax match ' .. filetype .. 'CommentLeader'
        .. ' /\%(^\s*\)\@<=' .. cml .. '/'
        .. ' contained'
enddef

def SynCommenttitle( #{{{2
    filetype: string,
    cml: string,
    nr: number
)
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
    if index(['html', 'vim'], filetype) >= 0
        return
    endif

    execute 'syntax match ' .. filetype .. 'CommentTitleLeader'
        .. ' /' .. cml .. '\s\+/ms=s+' .. nr
        .. ' contained'
    # Don't remove `containedin=`!{{{
    #
    # We need  it, for example,  to allow  `awkCommentTitle` to be  contained in
    # `awkComment`.  Same thing for many other filetypes.
    #}}}
    execute 'syntax match ' .. filetype .. 'CommentTitle'
        .. ' /' .. cml .. '\s*\u\w*\%(\s\+\u\w*\)*:/hs=s+' .. nr
        .. ' contained'
        .. ' containedin=' .. filetype .. 'Comment' .. (filetype == 'c' ? 'L' : '')
        .. ' contains=' .. filetype .. 'CommentTitleLeader,'
        .. filetype .. 'Todo'
enddef

def SynListItem( #{{{2
    filetype: string,
    cml: string,
    commentGroup: string
)
    execute 'syntax cluster ' .. filetype .. 'CommentListItemElements'
        .. ' contains=' .. filetype .. 'CommentListItemItalic,'
                        .. filetype .. 'CommentListItemBold,'
                        .. filetype .. 'CommentListItemBoldItalic,'
                        .. filetype .. 'CommentListItemCodeSpan,'
                        .. filetype .. 'CommentListItemCodeBlock,'
                        .. filetype .. 'CommentListItemOutput,'
                        .. '@Spell'

    # - some item 1
    #   some text
    #
    # - some item 2
    var list_marker: string = '[-*+]'
    execute 'syntax region ' .. filetype .. 'CommentListItem'
        .. ' start=/\%(^\s*\)\@<=' .. cml .. ' \{,4\}\%(' .. list_marker .. '\|\d\+\.\)\s\+\S/'
        # an empty line (except for the comment leader), followed by a non-empty line
        .. ' end=/' .. cml .. '\ze\s*\n\s*' .. cml .. ' \{,4}\S'
        # the end/beginning of a fold right after the end of the list (no empty line in between)
        .. '\|\n\ze\s*' .. cml .. '.*\%(}' .. '}}\|{' .. '{{\)'
        # a non-commented line
        .. '\|^\%(\s*' .. cml .. '\)\@!/'
        .. ' keepend'
        .. ' contains=' .. filetype .. 'FoldMarkers,'
                        .. filetype .. 'CommentLeader,'
                 .. '@' .. filetype .. 'CommentListItemElements'
        .. ' contained'
        .. ' containedin=' .. commentGroup
enddef

def SynCodeBlock( #{{{2
    filetype: string,
    cml: string,
    commentGroup: string
)
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
    execute 'syntax region ' .. filetype .. 'CommentCodeBlock'
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
    execute 'syntax region ' .. filetype .. 'CommentListItemCodeBlock'
        .. ' matchgroup=Comment'
        .. ' start=/\%(^\s*\)\@<=' .. cml .. ' \{9,}/'
        .. ' end=/$/'
        .. ' keepend'
        .. ' contained'
        .. ' containedin=' .. filetype .. 'CommentListItem'
        .. ' oneline'
enddef

def SynCodeSpan(filetype: string, commentGroup: string) #{{{2
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
    # From `:help :syn-matchgroup`:
    #
    #    > "matchgroup" can  be used to  highlight the start and/or  end pattern
    #    > differently than the body of the region.
    #}}}
    # Why do you need it here?{{{
    #
    # Without it, the surrounding markers are not concealed.
    # From `:help :syn-concealends`:
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
    execute 'syntax region ' .. filetype .. 'CommentCodeSpan'
        .. ' matchgroup=Comment'
        .. ' start=/\z(`\+\)/'
        .. ' end=/\z1/'
        .. ' keepend'
        .. ' concealends'
        .. ' contained'
        .. ' containedin=' .. commentGroup
        .. ' oneline'

    # - some `code span` item
    execute 'syntax region ' .. filetype .. 'CommentListItemCodeSpan'
        .. ' matchgroup=markdownListItem'
        .. ' start=/\z(`\+\)/'
        .. ' end=/\z1/'
        .. ' keepend'
        .. ' concealends'
        .. ' contained'
        .. ' oneline'

    # > some `code span` in a quote
    execute 'syntax region ' .. filetype .. 'CommentBlockquoteCodeSpan'
        .. ' matchgroup=markdownBlockquote'
        .. ' start=/\z(`\+\)/'
        .. ' end=/\z1/'
        .. ' keepend'
        .. ' concealends'
        .. ' contained'
        .. ' containedin=' .. filetype .. 'CommentBlockquote'
        .. ' oneline'
enddef

def SynItalic(filetype: string, commentGroup: string) #{{{2
    # It's impossible  to reliably  support the  italic style  in a  css buffer,
    # because the comment leader includes a star.
    # See our comments about the pitfall to avoid when trying to add support for
    # `cComment`.
    if filetype == 'css'
        return
    endif

    # some *italic* comment
    execute 'syntax region ' .. filetype .. 'CommentItalic'
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
    execute 'syntax region ' .. filetype .. 'CommentListItemItalic'
        .. ' matchgroup=markdownListItem'
        .. ' start=/\*/'
        .. ' end=/\*/'
        .. ' keepend'
        .. ' concealends'
        .. ' contained'
        .. ' contains=@Spell'
        .. ' oneline'

    # > some *italic* quote
    execute 'syntax region ' .. filetype .. 'CommentBlockquoteItalic'
        .. ' matchgroup=markdownBlockquote'
        .. ' start=/\*/'
        .. ' end=/\*/'
        .. ' keepend'
        .. ' concealends'
        .. ' contained'
        .. ' containedin=' .. filetype .. 'CommentBlockquote'
        .. ' contains=@Spell'
        .. ' oneline'
enddef

def SynBold(filetype: string, commentGroup: string) #{{{2
    # some **bold** comment
    execute 'syntax region ' .. filetype .. 'CommentBold'
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
    execute 'syntax region ' .. filetype .. 'CommentListItemBold'
        .. ' matchgroup=markdownListItem'
        .. ' start=/\*\*/'
        .. ' end=/\*\*/'
        .. ' keepend'
        .. ' concealends'
        .. ' contained'
        .. ' contains=@Spell'
        .. ' oneline'

    # > some **bold** quote
    execute 'syntax region ' .. filetype .. 'CommentBlockquoteBold'
        .. ' matchgroup=markdownBlockquote'
        .. ' start=/\*\*/'
        .. ' end=/\*\*/'
        .. ' keepend'
        .. ' concealends'
        .. ' contained'
        .. ' containedin=' .. filetype .. 'CommentBlockquote'
        .. ' contains=@Spell'
        .. ' oneline'
enddef

def SynBolditalic(filetype: string, commentGroup: string) #{{{2
    # some ***bold and italic*** comment
    execute 'syntax region ' .. filetype .. 'CommentBoldItalic'
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
    execute 'syntax region ' .. filetype .. 'CommentListItemBoldItalic'
        .. ' matchgroup=markdownListItem'
        .. ' start=/\*\*\*/'
        .. ' end=/\*\*\*/'
        .. ' keepend'
        .. ' concealends'
        .. ' contained'
        .. ' contains=@Spell'
        .. ' oneline'

    # > some ***bold and italic*** quote
    execute 'syntax region ' .. filetype .. 'CommentBlockquoteBoldItalic'
        .. ' matchgroup=markdownBlockquote'
        .. ' start=/\*\*\*/'
        .. ' end=/\*\*\*/'
        .. ' keepend'
        .. ' concealends'
        .. ' contained'
        .. ' containedin=' .. filetype .. 'CommentBlockquote'
        .. ' contains=@Spell'
        .. ' oneline'
enddef

def SynBlockquote( #{{{2
    filetype: string,
    cml: string,
    commentGroup: string
)
    # > some quote
    # <not> a quote
    # Why do you allow `xCommentBold` to be contained in `xCommentBlockquote`?{{{
    #
    # In a  markdown buffer,  we can make  some text be  displayed in  bold even
    # inside a blockquote.
    # To stay  consistent, we should be able  to do the same in  the comments of
    # other filetypes.
    #}}}
    execute 'syntax match ' .. filetype .. 'CommentBlockquote'
        .. ' /' .. cml .. '\\\= \{,4}>.*/'
        .. ' contained'
        .. ' containedin=' .. commentGroup
        .. ' contains=' .. filetype .. 'CommentLeader,'
                        .. filetype .. 'CommentBold,'
                        .. filetype .. 'CommentBlockquoteConceal,'
                        .. '@Spell'
        .. ' oneline'

    execute 'syntax match ' .. filetype .. 'CommentBlockquoteConceal'
        .. ' /\%(' .. cml .. '\\\= \{,4}\)\@<=>\s\=/'
        .. ' contained'
        .. ' conceal'

    # -   some list item
    #
    #     > some quote
    #
    # -   some list item
    execute 'syntax match ' .. filetype .. 'CommentListItemBlockquote'
        .. ' /' .. cml .. ' \{5}>.*/'
        .. ' contained'
        .. ' containedin=' .. filetype .. 'CommentListItem'
        .. ' contains=' .. filetype .. 'CommentLeader,'
                        .. filetype .. 'CommentBlockquoteBold,'
                        .. filetype .. 'CommentListItemBlockquoteConceal,'
                        .. '@Spell'
        .. ' oneline'

    execute 'syntax match ' .. filetype .. 'CommentListItemBlockquoteConceal'
        .. ' /\%(' .. cml .. ' \{5}\)\@<=>\s\=/'
        .. ' contained'
        .. ' conceal'
enddef

def SynOutput(filetype: string) #{{{2
    #     $ shell command
    #     output˜
    execute 'syntax match ' .. filetype .. 'CommentOutput'
        .. ' /.*˜$/'
        .. ' contained'
        .. ' containedin=' .. filetype .. 'CommentCodeBlock'
        .. ' nextgroup=' .. filetype .. 'CommentIgnore'

    execute 'syntax match ' .. filetype .. 'CommentIgnore'
        .. ' /.$/'
        .. ' contained'
        .. ' containedin=' .. filetype .. 'CommentOutput,'
                           .. filetype .. 'CommentListItemOutput'
        .. ' conceal'

    # - some item
    #         some output˜
    execute 'syntax match ' .. filetype .. 'CommentListItemOutput'
        .. ' /.*˜$/'
        .. ' contained'
        .. ' containedin=' .. filetype .. 'CommentListItemCodeBlock'
        .. ' nextgroup=' .. filetype .. 'CommentIgnore'
enddef

def SynOption(filetype: string) #{{{2
    # some `'option'`
    # - some `'option'`
    execute 'syntax match ' .. filetype .. 'CommentOption'
        .. ' /`\@1<=''[a-z]\{2,}''\ze`/'
        .. ' contained'
        .. ' containedin=' .. filetype .. 'CommentCodeSpan,'
                           .. filetype .. 'CommentListItemCodeSpan'
enddef

def SynPointer( #{{{2
    filetype: string,
    cml: string,
    commentGroup: string
)
    # not a pointer v
    # v
    #       ^
    # ^---^
    # v---v
    #     "   ^---^
    execute 'syntax match ' .. filetype .. 'CommentPointer'
        .. ' /' .. cml .. '\s*\%(' .. cml .. '\)\=\s*\%([v^✘✔-]\+\s*\)\+$/'
        .. ' contains=' .. filetype .. 'CommentLeader'
        .. ' contained'
        .. ' containedin=' .. commentGroup
enddef

def SynRule( #{{{2
    filetype: string,
    cml: string,
    commentGroup: string
)
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
    execute 'syntax match ' .. filetype .. 'CommentRule'
        .. ' /' .. cml .. ' *- *- *-[ -]*$/'
        .. ' contained'
        .. ' containedin=' .. commentGroup
        .. ' contains=' .. filetype .. 'CommentLeader'
enddef

def SynTable( #{{{2
    filetype: string,
    cml: string,
    commentGroup: string
)
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
    execute 'syntax region ' .. filetype .. 'CommentTable'
        .. ' matchgroup=Comment'
        .. ' start=/' .. cml .. ' \{4,}\ze\%('
            ..         '┌[─┬┼]\+[┤┐]'
            .. '\|' .. '└[─┴]\+┘'
            .. '\|' .. '│[^┘┐]*[^┘┐ \t│][^┘┐]*│'
            .. '\|' .. '├─.*┤'
            .. '\|' .. '│.*├.*┤'
            .. '\)/'
        .. ' end=/$/'
        .. ' keepend'
        .. ' oneline'
        .. ' contained'
        .. ' containedin=' .. commentGroup
        .. ' contains=@Spell'
enddef

def SynUrl(filetype: string, commentGroup: string) #{{{2
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
    execute 'syntax match ' .. filetype
        .. 'CommentURL `\v<(((https=|ftp)://|file:)[^''  <>"]+|(www|web|w3)[a-z0-9_-]*\.[a-z0-9._-]+\.[^''  <>"]+)[a-zA-Z0-9/]`'
        .. ' contained'
        .. ' containedin=' .. commentGroup
enddef

def SynFoldmarkers( #{{{2
    filetype: string,
    cml_0_1: string,
    commentGroup: string
)
    # If you don't care about html and css, you could probably simplify the code
    # of this function, and get rid of `cml_right`.

    # replace noisy markers, used in folds, with ❭ and ❬
    # Why not `containedin=ALL`?{{{
    #
    # Run:
    #
    #     :setlocal conceallevel=2
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
    var cml_left: string = '\V' .. &l:commentstring->matchstr('\S*\ze\s*%s')->escape('\/') .. '\m'
    var cml_right: string = '\V' .. &l:commentstring->matchstr('.*%s\s*\zs.*')->escape('\/') .. '\m'
    var pat: string
    var contained: string
    if cml_right == '\V\m'
        pat = cml_0_1 .. '\s*\%({' .. '{{\|}' .. '}}\)\d*\s*\ze\n'
        contained = ' contained'
    else
        pat = '\s*' .. cml_left .. '\s*\%({' .. '{{\|}' .. '}}\)\d*\s*' .. cml_right .. '\s*$'
        contained = ''
    endif
    execute 'syntax match ' .. filetype .. 'FoldMarkers'
        .. ' /' .. pat .. '/'
        .. ' conceal'
        .. ' cchar=❭'
        .. ' contains=' .. filetype .. 'CommentLeader'
        .. contained
        .. ' containedin=' .. commentGroup
                    .. ',' .. filetype .. 'CommentCodeBlock'
enddef

