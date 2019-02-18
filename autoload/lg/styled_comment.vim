" Whenever you create or remove a custom syntax group from `lg#styled_comment#syntax()`, update `s:custom_groups`!{{{
"
" Otherwise, you may have a broken syntax highlighting in any filetype whose
" default syntax plugin uses `ALLBUT`.
"
" `s:custom_groups` is used by `s:syn_mycustomgroups()` to define `@MyCustomGroups`.
" We  sometimes use  this  cluster in  `after/syntax/x.vim`  to exclude  our
" custom groups from the ones installed by a default syntax plugin.
"}}}
" Init {{{1

let s:custom_groups = [
    \ 'CommentBlockquote',
    \ 'CommentBlockquoteBold',
    \ 'CommentBlockquoteBoldItalic',
    \ 'CommentBlockquoteCodeSpan',
    \ 'CommentBlockquoteConceal',
    \ 'CommentBlockquoteItalic',
    \ 'CommentBold',
    \ 'CommentBoldItalic',
    \ 'CommentCodeBlock',
    \ 'CommentCodeSpan',
    \ 'CommentIgnore',
    \ 'CommentItalic',
    \ 'CommentKey',
    \ 'CommentLeader',
    \ 'CommentListItem',
    \ 'CommentListItemBlockquote',
    \ 'CommentListItemBlockquoteConceal',
    \ 'CommentListItemBold',
    \ 'CommentListItemBoldItalic',
    \ 'CommentListItemCodeBlock',
    \ 'CommentListItemCodeSpan',
    \ 'CommentListItemItalic',
    \ 'CommentOption',
    \ 'CommentOutput',
    \ 'CommentPointer',
    \ 'CommentRule',
    \ 'CommentTable',
    \ 'CommentTitle',
    \ 'CommentTitleLeader',
    \ 'FoldMarkers',
    \ '@CommentListItemElements',
\ ]
" }}}1

" filetype plugin {{{1
fu! lg#styled_comment#fold() abort "{{{2
    let ft = expand('<amatch>')
    exe 'augroup my_'.ft
        au! *            <buffer>
        au  BufWinEnter  <buffer>  setl fdm=marker
                               \ | setl fdt=fold#fdt#get()
                               \ | setl cocu=nc
                               \ | setl cole=3
    augroup END
endfu

fu! lg#styled_comment#undo_ftplugin() abort "{{{2
    let ft = expand('<amatch>')
    let b:undo_ftplugin = get(b:, 'undo_ftplugin', '')
        \ . (empty(get(b:, 'undo_ftplugin', '')) ? '' : '|')
        \ . "
        \   setl cocu< cole< fdm< fdt<
        \ | exe 'au! my_".ft." * <buffer>'
        \ "
endfu
" }}}1
" syntax plugin {{{1
fu! s:get_filetype() abort "{{{2
    let ft = expand('<amatch>')
    if ft is# 'snippets' | let ft = 'snip' | endif
    return ft
endfu

fu! s:highlight_groups_links(ft) abort "{{{2
    exe 'hi '.a:ft.'FoldMarkers term=bold cterm=bold gui=bold'

    exe 'hi link '.a:ft.'CommentBold                  CommentBold'
    exe 'hi link '.a:ft.'CommentBoldItalic            CommentBoldItalic'
    exe 'hi link '.a:ft.'CommentCodeBlock             CommentCodeSpan'
    exe 'hi link '.a:ft.'CommentCodeSpan              CommentCodeSpan'
    exe 'hi link '.a:ft.'CommentItalic                CommentItalic'

    exe 'hi link '.a:ft.'CommentBlockquote            markdownBlockquote'
    exe 'hi link '.a:ft.'CommentBlockquoteBold        markdownBlockquoteBold'
    exe 'hi link '.a:ft.'CommentBlockquoteBoldItalic  markdownBlockquoteBoldItalic'
    exe 'hi link '.a:ft.'CommentBlockquoteCodeSpan    markdownBlockquoteCodeSpan'
    exe 'hi link '.a:ft.'CommentBlockquoteItalic      markdownBlockquoteItalic'

    exe 'hi link '.a:ft.'CommentKey                   markdownKey'
    exe 'hi link '.a:ft.'CommentLeader                Comment'
    exe 'hi link '.a:ft.'CommentListItem              markdownListItem'
    exe 'hi link '.a:ft.'CommentListItemBlockquote    markdownListItemBlockquote'
    exe 'hi link '.a:ft.'CommentListItemBold          markdownListItemBold'
    exe 'hi link '.a:ft.'CommentListItemBoldItalic    markdownListItemBoldItalic'
    exe 'hi link '.a:ft.'CommentListItemCodeBlock     CommentCodeSpan'
    exe 'hi link '.a:ft.'CommentListItemCodeSpan      CommentListItemCodeSpan'
    exe 'hi link '.a:ft.'CommentListItemItalic        markdownListItemItalic'
    exe 'hi link '.a:ft.'CommentOption                markdownOption'
    exe 'hi link '.a:ft.'CommentOutput                PreProc'
    exe 'hi link '.a:ft.'CommentPointer               markdownPointer'
    exe 'hi link '.a:ft.'CommentRule                  markdownRule'
    exe 'hi link '.a:ft.'CommentTable                 markdownTable'
    exe 'hi link '.a:ft.'CommentTitle                 PreProc'
endfu

fu! lg#styled_comment#syntax() abort "{{{2
    " Use `\s` instead of ` `!{{{
    "
    " This is necessary for a whitespace before a comment leader:
    "
    "     /^ ...
    "       ^
    "       ✘
    "
    "     /^\s...
    "       ^^
    "       ✔
    "
    " Because, there's  no guarantee  that the file  you're reading  is indented
    " with spaces.
    " To be consistent, we should always use `\s`, even for a whitespace *after*
    " the comment leader.
    "
    " ` {,N}` is an exception. I think it's ok to use a literal space in this case.
    " Tpope does it a few times in his markdown syntax plugin.
    "}}}

    " Never write `matchgroup=xGroup` with `xGroup` being a builtin HG.{{{
    "
    " `xGroup` should be a *custom* HG, that we can customize in our colorscheme.
    " This function should *not* be charged with setting the colors of the comments.
    " It should only set the syntax.
    " This  way, we  can  change the  color  of a  type  of comment  (codeblock,
    " blockquote,  table,... ),  uniformly across  all filetypes  from a  single
    " location:
    "
    "     ~/.vim/autoload/colorscheme.vim
    "}}}
    " Be careful before using `^\s*` in a regex!{{{
    "
    " Some default syntax plugins define a  comment from the comment leader, not
    " from the beginning of the line,  either by omitting `^\s*` or by excluding
    " it with `\zs`.
    "
    "     $VIMRUNTIME/syntax/sh.vim:376
    "     $VIMRUNTIME/syntax/lua.vim:34
    "
    " Besides, all your custom items are contained in a comment.
    " If you define one of them with  `^\s*` it will begin from the beginning of
    " the line.
    " But if the line is indented,  the comment will begin *after* the beginning
    " of the line,  which will prevent your custom item  from being contained in
    " the comment.
    " As a result, its syntax highlighting will be broken.
    "
    " Atm, this issue applies to:
    "
    " - CommentBlockquote
    " - CommentCodeBlock
    " - CommentListItem
    " - CommentPointer
    " - CommentTable
    "}}}
        " What if I need `^\s*`?{{{
        "
        " Exclude it from the item with `\%(...\)\@<=`.
        " Make some tests with `:syntime` to measure the impact on performance.
    "}}}
        " Is it ok if I omit `^\s*`?{{{
        "
        " I think it's ok, because:
        "
        " 1. all these groups are contained in a comment;
        "    so if an undesired match could occur, it would be in a comment
        "
        " 2. they match whole lines (up to the end) from the first comment leader;
        "    so if an undesired match could occur, it would be in the item itself
        "
        " 3. they don't contain themselves
        "
        " Exception:
        "
        " For  `CommentListItem`, you  *have* to  use `\%(^\s*\)\@<=`,  probably
        " because it's a multi-line item.
        " Otherwise, you could  have an undesired list starting  from the middle
        " of a comment.
        "
        " Example in a lua file:
        "
        "     -- some comment -- - wrongly highlighted as list item
        "                        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
        "}}}

    " TODO: integrate most of the comments from this function into our notes

    " TODO: find a consistent order for the arguments of a region (and other items)
    " and stick to it (here and in the markdown syntax plugin)

    let ft = s:get_filetype()
    let cml = matchstr(get(split(&l:cms, '%s'), 0, ''), '\S*')
    " What do you need this `nr` for?{{{
    "
    " For offsets when defining the syntax groups:
    "
    "     - xxxCommentTitle
    "     - xxxCommentTitleLeader
    "}}}
    " Why capturing it now?{{{
    "
    " The next statement invokes `escape()` which may add backslashes, and alter
    " the real number of characters inside the comment leader.
    "}}}
    let nr = strchars(cml, 1)
    " Why do you escape the slashes?{{{
    "
    " We use a slash as a delimiter around the patterns of our syntax elements.
    " As a  result, if  the comment  leader of the  current filetype  contains a
    " slash, we need to escape the slashes to prevent Vim from interpreting them
    " as the end of the pattern.
    " This is needed for `xkb` where the comment leader is `//`.
    "}}}
    " FIXME: A commented code block is not properly highlighted in a C buffer.{{{
    "
    " Escaping `*` fixes the issue.
    " Why? `\V` should be enough.
    "}}}
    let cml = escape(cml, '/*\')
    let cml_0_1 = '\V\%('.cml.'\)\=\m'
    let cml = '\V'.cml.'\m'
    let commentGroup = ft.'Comment'.(ft is# 'vim' ? ',vimLineComment' : '')

    call s:syn_commentleader(ft, cml)
    call s:syn_commenttitle(ft, cml, nr)
    call s:syn_list_item(ft, cml, commentGroup)
    " Don't move this call somewhere below!{{{
    "
    " `xCommentPointer` must be defined *after* `xCommentCodeBlock`.
    "
    " Otherwise its  highlighting would  fail when the  pointer is  located more
    " than 4 characters away from the comment leader.
    " I suspect there are other items which may sometimes break if they're defined
    " before `xCommentCodeBlock`.
    "
    " So, unless you know what you're doing, leave this call here.
    "}}}
    call s:syn_code_block(ft, cml, commentGroup)
    call s:syn_code_span(ft, commentGroup)
    " Don't change the order of `s:syn_italic()`, `s:syn_bold()` and `s:syn_bolditalic()`!{{{
    "
    " It would break the syntax highlighting of some style (italic, bold, bold+italic).
    "}}}
    " Why?{{{
    "
    " Because   we  haven't   defined   the   syntax  groups   `xCommentItalic`,
    " `xCommentBold`, `xCommentBoldItalic` accurately.
    " For  example, this  region is  not accurate enough  to describe  an italic
    " element:
    "
    "     syn region xCommentItalic start=/\*/ end=/\*/
    "
    " A text in bold wrongly matches this description.
    " This would be more accurate:
    "
    "     syn region xCommentItalic start=/\*\@1<!\*\*\@!/ end=/\*\@1<!\*\*\@!/
    "
    " But it would probably have an impact on Vim's performance.
    "}}}
    call s:syn_italic(ft, commentGroup)
    call s:syn_bold(ft, commentGroup)
    call s:syn_bolditalic(ft, commentGroup)
    call s:syn_blockquote(ft, cml, commentGroup)
    call s:syn_output(ft, cml)
    " TODO: This invocation of `s:syn_option()` doesn't require several arguments.
    " This  is neat;  study how  it's possible,  and try  to redefine  the other
    " syntax groups, so that we have less arguments to pass.
    call s:syn_option(ft)
    call s:syn_pointer(ft, cml, commentGroup)
    call s:syn_key(ft, commentGroup)
    call s:syn_rule(ft, cml, commentGroup)
    call s:syn_table(ft, cml, commentGroup)
    call s:syn_foldmarkers(ft, cml_0_1, commentGroup)
    " What does it do?{{{
    "
    " It defines  a cluster  containing all  the custom  syntax groups  that the
    " current function has defined.
    "}}}
        " Why?{{{
        "
        " Some default syntax plugins define groups with the argument `contains=ALLBUT`.
        " It means that they can contain *anything* except a few specific groups.
        " Because of this, they can contain our custom groups.
        " And as a result, our code may be applied wrong graphical attributes:
        "
        "     $ cat <<'EOF' >/tmp/lua.lua
        "     ( 1 * 2 * 3 )
        "     EOF
        "
        "     $ vim !$
        "
        " We need an easy way to tell  Vim that these default groups must *also*
        " exclude our custom groups.
        "}}}
        " How can this custom cluster be used?{{{
        "
        " When a default syntax plugin uses the arguments `contains=ALLBUT,...`,
        " clear it (`:syn clear ...`) and redefine it in `after/syntax/x.vim`.
        " Use the same original definition, with one change:
        " add `@xMyCustomGroups` after `contains=ALLBUT,...`.
        " }}}
    call s:syn_mycustomgroups(ft)

    call s:highlight_groups_links(ft)

    " TODO: highlight commented urls (like in markdown)?{{{
    "
    "     markdownLinkText xxx matchgroup=markdownLinkTextDelimiter
    "                          start=/!\=\[\%(\_[^]]*]\%(\s\=[[(]\)\)\@=/
    "                          end=/\]\%(\s\=[[(]\)\@=/
    "                          concealends
    "                          contains=@markdownInline,markdownLineStart
    "                          nextgroup=markdownLink,markdownId
    "                          skipwhite
    "     links to Conditional
    "
    "     markdownUrl    xxx match /\S\+/
    "                        contained nextgroup=markdownUrlTitle
    "                        skipwhite
    "                        matchgroup=markdownUrlDelimiter
    "                        start=/</
    "                        end=/>/
    "                        contained
    "                        oneline
    "                        keepend
    "                        nextgroup=markdownUrlTitle
    "                        skipwhite
    "     links to Float
    "}}}
    " TODO:{{{
    " Read:
    "     https://daringfireball.net/projects/markdown/syntax
    "     https://daringfireball.net/projects/markdown/basics
    "
    " `markdown` provides some useful syntax which our comments
    " don't emulate yet.
    "
    " Like the fact that  a list item can include a blockquote  or a code block.
    " Make some tests on github,  stackexchange, reddit, and with `:Preview`, to
    " see what the current syntax is (markdown has evolved I guess...).
    "
    " And try to emulate every interesting syntax you find.
    "}}}
endfu

fu! s:syn_commentleader(ft, cml) abort "{{{2
    " Why `\%(^\s*\)\@<=`?{{{
    "
    " Without it, if your comment leader appears inside a list item, it would be
    " highlighted as a comment leader, instead of being part of the item.
    "}}}
    exe 'syn match '.a:ft.'CommentLeader'
        \ . ' /\%(^\s*\)\@<='.a:cml.'/'
        \ . ' contained'
endfu

fu! s:syn_commenttitle(ft, cml, nr) abort "{{{2
    if a:ft isnot# 'vim'
        " TODO: Explain how the code works.
        " Don't remove `containedin=`!{{{
        "
        " We need it, for example, to allow `awkCommentTitle` to be contained in
        " `awkComment`. Same thing for other many other filetypes.
        "}}}
        exe 'syn match '.a:ft.'CommentTitle'
            \ . ' /'.a:cml.'\s*\u\w*\%(\s\+\u\w*\)*:/hs=s+'.a:nr
            \ . ' contained'
            \ . ' containedin='.a:ft.'Comment'
            \ . ' contains='.a:ft.'CommentTitleLeader,'
            \ .              a:ft.'Todo'

        exe 'syn match '.a:ft.'CommentTitleLeader'
            \ . ' /'.a:cml.'\s\+/ms=s+'.a:nr
            \ . ' contained'
    endif
endfu

fu! s:syn_list_item(ft, cml, commentGroup) abort "{{{2
    exe 'syn cluster '.a:ft.'CommentListItemElements'
        \ . ' contains='.a:ft.'CommentListItemItalic,'
        \ .              a:ft.'CommentListItemBold,'
        \ .              a:ft.'CommentListItemBoldItalic,'
        \ .              a:ft.'CommentListItemCodeSpan,'
        \ .              a:ft.'CommentListItemCodeBlock,'

    " - some item 1
    "   some text
    "
    " - some item 2
    " The end pattern is long... What does it mean?{{{
    "
    " It contains 3 main branches.
    "
    " An empty  line (except for  the comment  leader), followed by  a non-empty
    " line:
    "
    "     cml.'\%(\s*\n\s*'.cml.'\s\=\S\)\@='
    "
    " The end/beginning of a fold right after the end of the list (no empty line
    " in-between):
    "
    "     '\n\%(\s*'.cml.'.*\%(}'.'}}\|{'.'{{\)\)\@='
    "
    " A non-commented line:
    "
    "     '^\%(\s*'.cml.'\)\@!'
    "}}}
    " The regexes include several lookafter with quantifiers.  Do they cause bad performance?{{{
    "
    " Weirdly enough, no.
    " With and without limiting the backtracking of `\%(^\s*\)\@<=`.
    "}}}
    " Why excluding `*` as a list marker?{{{
    "
    " In a C buffer,  it would cause the second line of a  multi-line (up to the
    " last one) to be wrongly highlighted as a list item.
    "}}}
    let list_marker = a:ft is# 'c' ? '[-+]' : '[-*+]'
    exe 'syn region '.a:ft.'CommentListItem'
        \ . ' start=/\%(^\s*\)\@<='.a:cml.' \{,4\}\%('.list_marker.'\|\d\+\.\)\s\+\S/'
        \ . ' end=/'.a:cml.'\%(\s*\n\s*'.a:cml.' \{,4}\S\)\@='
        \       . '\|\n\%(\s*'.a:cml.'.*\%(}'.'}}\|{'.'{{\)\)\@='
        \       . '\|^\%(\s*'.a:cml.'\)\@!/'
        \ . ' keepend'
        \ . ' contains='.a:ft.'FoldMarkers,'
        \ .              a:ft.'CommentLeader,'
        \ .          '@'.a:ft.'CommentListItemElements'
        \ . ' contained'
        \ . ' containedin='.a:commentGroup
endfu

fu! s:syn_code_block(ft, cml, commentGroup) abort "{{{2
    " Why a region?{{{
    "
    " I  want `xCommentCodeBlock`  to highlight  only  after 5  spaces from  the
    " comment leader (instead of complete lines).
    " It's less noisy.
    "}}}
    exe 'syn region '.a:ft.'CommentCodeBlock'
        \ . ' matchgroup=Comment'
        \ . ' start=/'.a:cml.' \{5,}/'
        \ . ' end=/$/'
        \ . ' keepend'
        \ . ' contained'
        \ . ' containedin='.a:commentGroup
        \ . ' oneline'

    " - some item
    "
    "         some code block
    "
    " - some item
    exe 'syn region '.a:ft.'CommentListItemCodeBlock'
        \ . ' matchgroup=Comment'
        \ . ' start=/'.a:cml.'         /'
        \ . ' end=/$/'
        \ . ' keepend'
        \ . ' contained'
        \ . ' containedin='.a:ft.'CommentListItem'
        \ . ' oneline'
endfu

fu! s:syn_code_span(ft, commentGroup) abort "{{{2
    " What does `matchroup` do?{{{
    "
    " From `:h :syn-matchgroup`:
    "
    " >    "matchgroup" can  be used to  highlight the start and/or  end pattern
    " >    differently than the body of the region.
    "}}}
    " Why do you need it here?{{{
    "
    " Without it, the surrounding markers are not concealed.
    " From `:h :syn-concealends`:
    "
    " >    The ends  of a region  can only be  concealed separately in  this way
    " >    when they have their own highlighting via "matchgroup"
    "}}}
    " Is the `contained` argument necessary for all syntax items?{{{
    "
    " Probably not, but better be safe than sorry.
    "
    " You must use `contained` when the item may match at the top level, and you
    " don't want to.
    "
    " It's definitely necessary for:
    "
    "     CommentCodeSpan
    "     CommentItalic
    "     CommentBold
    "
    " Otherwise, your code may be applied wrong graphical attributes:
    "
    "     $ cat <<'EOF' >/tmp/awk.awk
    "     * word *
    "     ` word `
    "     ** word **
    "     EOF
    "
    "     $ vim !$
    "}}}
    " some `code span` in a comment
    exe 'syn region '.a:ft.'CommentCodeSpan'
        \ . ' matchgroup=Comment'
        \ . ' start=/\z(`\+\)/'
        \ . '   end=/\z1/'
        \ . ' keepend'
        \ . ' concealends'
        \ . ' contained'
        \ . ' containedin='.a:commentGroup
        \ . ' oneline'

    " - some `code span` item
    exe 'syn region '.a:ft.'CommentListItemCodeSpan'
        \ . ' matchgroup=markdownListItem'
        \ . ' start=/\z(`\+\)/'
        \ . '   end=/\z1/'
        \ . ' keepend'
        \ . ' concealends'
        \ . ' contained'
        \ . ' oneline'

    " > some `code span` in a quote
    exe 'syn region '.a:ft.'CommentBlockquoteCodeSpan'
        \ . ' matchgroup=markdownBlockquote'
        \ . ' start=/\z(`\+\)/'
        \ . '   end=/\z1/'
        \ . ' keepend'
        \ . ' concealends'
        \ . ' contained'
        \ . ' containedin='.a:ft.'CommentBlockquote'
        \ . ' oneline'
endfu

fu! s:syn_italic(ft, commentGroup) abort "{{{2
    " some *italic* comment
    " Why `\*\S` instead of just `\*`?{{{
    "
    " In a C  buffer, it would cause the  text on the last line  of a multi-line
    " comment to be wrongly emphasized in italic.
    "
    "     /* start of multi-line comment
    "     *  wrong emphasized in italic */
    "}}}
    exe 'syn region '.a:ft.'CommentItalic'
        \ . ' matchgroup=Comment'
        \ . ' start=/\*\%(\S\)\@=/'
        \ . '   end=/\*/'
        \ . ' keepend'
        \ . ' concealends'
        \ . ' contained'
        \ . ' containedin='.a:commentGroup
        \ . ' oneline'

    " - some *italic* item
    exe 'syn region '.a:ft.'CommentListItemItalic'
        \ . ' matchgroup=markdownListItem'
        \ . ' start=/\*/'
        \ . '   end=/\*/'
        \ . ' keepend'
        \ . ' concealends'
        \ . ' contained'
        \ . ' oneline'

    " > some *italic* quote
    exe 'syn region '.a:ft.'CommentBlockquoteItalic'
        \ . ' matchgroup=markdownBlockquote'
        \ . ' start=/\*/'
        \ . '   end=/\*/'
        \ . ' keepend'
        \ . ' concealends'
        \ . ' contained'
        \ . ' containedin='.a:ft.'CommentBlockquote'
        \ . ' oneline'
endfu

fu! s:syn_bold(ft, commentGroup) abort "{{{2
    " some **bold** comment
    exe 'syn region '.a:ft.'CommentBold'
        \ . ' matchgroup=Comment'
        \ . ' start=/\*\*/'
        \ . '  end=/\*\*/'
        \ . ' keepend'
        \ . ' concealends'
        \ . ' contained'
        \ . ' containedin='.a:commentGroup
        \ . ' oneline'

    " - some **bold** item
    exe 'syn region '.a:ft.'CommentListItemBold'
        \ . ' matchgroup=markdownListItem'
        \ . ' start=/\*\*/'
        \ . '  end=/\*\*/'
        \ . ' keepend'
        \ . ' concealends'
        \ . ' contained'
        \ . ' oneline'

    " > some **bold** quote
    exe 'syn region '.a:ft.'CommentBlockquoteBold'
        \ . ' matchgroup=markdownBlockquote'
        \ . ' start=/\*\*/'
        \ . '   end=/\*\*/'
        \ . ' keepend'
        \ . ' concealends'
        \ . ' contained'
        \ . ' containedin='.a:ft.'CommentBlockquote'
        \ . ' oneline'
endfu

fu! s:syn_bolditalic(ft, commentGroup) abort "{{{2
    " some ***bold and italic*** comment
    exe 'syn region '.a:ft.'CommentBoldItalic'
        \ . ' matchgroup=Comment'
        \ . ' start=/\*\*\*/'
        \ . '  end=/\*\*\*/'
        \ . ' keepend'
        \ . ' concealends'
        \ . ' contained'
        \ . ' containedin='.a:commentGroup
        \ . ' oneline'

    " - some ***bold and italic*** item
    exe 'syn region '.a:ft.'CommentListItemBoldItalic'
        \ . ' matchgroup=markdownListItem'
        \ . ' start=/\*\*\*/'
        \ . '  end=/\*\*\*/'
        \ . ' keepend'
        \ . ' concealends'
        \ . ' contained'
        \ . ' oneline'

    " > some ***bold and italic*** quote
    exe 'syn region '.a:ft.'CommentBlockquoteBoldItalic'
        \ . ' matchgroup=markdownBlockquote'
        \ . ' start=/\*\*\*/'
        \ . '  end=/\*\*\*/'
        \ . ' keepend'
        \ . ' concealends'
        \ . ' contained'
        \ . ' containedin='.a:ft.'CommentBlockquote'
        \ . ' oneline'
endfu

fu! s:syn_blockquote(ft, cml, commentGroup) abort "{{{2
    " > some quote
    " <not> a quote
    " Why do you allow `xCommentBold` to be contained in `xCommentBlockquote`?{{{
    "
    " In a  markdown buffer,  we can make  some text be  displayed in  bold even
    " inside a blockquote.
    " To stay  consistent, we should be able  to do the same in  the comments of
    " other filetypes.
    "}}}
    exe 'syn match '.a:ft.'CommentBlockquote'
        \ . ' /'.a:cml.' \{,4}>.*/'
        \ . ' contained'
        \ . ' containedin='.a:commentGroup
        \ . ' contains='.a:ft.'CommentLeader,'
        \ .              a:ft.'CommentBold,'
        \ .              a:ft.'CommentBlockquoteConceal'
        \ . ' oneline'

    exe 'syn match '.a:ft.'CommentBlockquoteConceal'
        \ . ' /\%('.a:cml.' \{,4}\)\@<=>\s\=/'
        \ . ' contained'
        \ . ' conceal'

    " -   some list item
    "
    "     > some quote
    "
    " -   some list item
    exe 'syn match '.a:ft.'CommentListItemBlockquote'
        \ . ' /'.a:cml.' \{5}>.*/'
        \ . ' contained'
        \ . ' containedin='.a:ft.'CommentListItem'
        \ . ' contains='.a:ft.'CommentLeader,'
        \ .              a:ft.'CommentBlockquoteBold,'
        \ .              a:ft.'CommentListItemBlockquoteConceal'
        \ . ' oneline'

    exe 'syn match '.a:ft.'CommentListItemBlockquoteConceal'
        \ . ' /\%('.a:cml.' \{5}\)\@<=>\s\=/'
        \ . ' contained'
        \ . ' conceal'
endfu

fu! s:syn_output(ft, cml) abort "{{{2
    "     $ shell command
    "     output~
    " Why `\%(...\)\@<=` for these 2 statements?{{{
    "
    " It's required in the first statement because:
    "
    "    1. `xCommentOutput` is contained in `xCommentCodeBlock`
    "
    "    2. `xCommentCodeBlock` is a region using `matchgroup=`
    "
    "    3. `matchgroup=` prevents  a contained  item to  match where  `start` and
    "       `end` matched
    "
    " It's required in  the second statement because we don't  want to highlight
    " with `Ignore` *all* the output of a command, only the last tilde.
    "}}}
    exe 'syn match '.a:ft.'CommentOutput'
        \ . ' /\%(^\s*'.a:cml.' \{5,}\)\@<=.*\~$/'
        \ . ' contained'
        \ . ' containedin='.a:ft.'CommentCodeBlock'
        \ . ' nextgroup='.a:ft.'CommentIgnore'

    exe 'syn match '.a:ft.'CommentIgnore'
        \ . ' /\%(^\s*'.a:cml.'.*\)\@<=.$/'
        \ . ' contained'
        \ . ' containedin='.a:ft.'CommentOutput'
        \ . ' conceal'
endfu

fu! s:syn_option(ft) abort "{{{2
    " some `'option'`
    " - some `'option'`
    exe 'syn match '.a:ft.'CommentOption'
        \ . ' /`\@1<=''[a-z]\{2,}''`\@=/'
        \ . ' contained'
        \ . ' containedin='.a:ft.'CommentCodeSpan,'.a:ft.'CommentListItemCodeSpan'
endfu

fu! s:syn_pointer(ft, cml, commentGroup) abort "{{{2
    " not a pointer v
    " v
    "       ^
    exe 'syn match '.a:ft.'CommentPointer'
        \ . ' /'.a:cml.'\s*\%([v^✘✔]\+\s*\)\+$/'
        \ . ' contains='.a:ft.'CommentLeader'
        \ . ' contained'
        \ . ' containedin='.a:commentGroup
endfu

fu! s:syn_key(ft, commentGroup) abort "{{{2
    exe 'syn region '.a:ft.'CommentKey'
        \ . ' matchgroup=Special'
        \ . ' start=/<kbd>/'
        \ . ' end=/<\/kbd>/'
        \ . ' concealends'
        \ . ' contained'
        \ . ' containedin='.a:commentGroup
endfu

fu! s:syn_rule(ft, cml, commentGroup) abort "{{{2
    " Where does the regex come from?{{{
    "
    " Tpope uses a similar regex in his markdown syntax plugin:
    "
    "     - *- *-[ -]*$
    "
    " We  just add  ` *`  in front  of it,  because there  could be  some spaces
    " between the comment leader and a horizontal rule.
    "}}}
    exe 'syn match '.a:ft.'CommentRule'
        \ . ' /'.a:cml.' *- *- *-[ -]*$/'
        \ . ' contained'
        \ . ' containedin='.a:commentGroup
        \ . ' contains='.a:ft.'CommentLeader'
endfu

fu! s:syn_table(ft, cml, commentGroup) abort "{{{2
    " some table:
    "    ┌───────┬──────┐
    "    │  one  │ two  │
    "    ├───────┼──────┤
    "    │ three │ four │
    "    └───────┴──────┘
    " Note that the table must begin 4 spaces after the comment leader
    " (instead of 5 for a code block).
    " Why not using a tab character to distinguish between a code block and a table?{{{
    "
    " A tab character means that the distance between the comment leader and the
    " beginning  of the  table would  vary, depending  on the  current level  of
    " indentation of the comment.
    "
    " It's distracting, especially when you increase/decrease the indentation of
    " a comment.
    "}}}
    " Why don't you allow a code span to be contained in a table?{{{
    "
    " The concealing of the backticks would break the alignment of the table.
    " Although, I  guess you could  include a  code span without  concealing the
    " backticks, but you would need to define another code span syntax item.
    "}}}
    exe 'syn region '.a:ft.'CommentTable'
        \ . ' matchgroup=Comment'
        \ . ' start=/'.a:cml.'    \%([┌└]─\|│.*[^ \t│].*│\|├─.*┤\)\@=/'
        \ . ' end=/$/'
        \ . ' keepend'
        \ . ' oneline'
        \ . ' contained'
        \ . ' containedin='.a:commentGroup
endfu

fu! s:syn_foldmarkers(ft, cml_0_1, commentGroup) abort "{{{2
    " replace noisy markers, used in folds, with ❭ and ❬
    " Why not `containedin=ALL`?{{{
    "
    " Run:
    "
    "     :setl cole=2
    "
    " Result:
    "
    " If your fold  markers are prefixed by `n` whitespaces,  you will see `n+1`
    " conceal characters instead of just 1.
    "
    " For example:
    "
    "     SPC SPC { { {
    "
    " `SPC SPC { { {` will  be matched by the  regex `\s*{{ {`, and  so will be
    " concealed by the `❭` character.
    " But `SPC { { {` will also  be matched by  the regex,  and `xFoldMarkers`
    " *can* be contained in itself (at a later position), so it will *also* be
    " concealed by the `❭` character.
    " Same thing for `{ { {` (without space).
    "
    " In the end, you will have 3 conceal characters, instead of 1.
    "}}}
    " The conceal markers are barely readable!{{{
    "
    " Try more thick ones:
    "
    "    ❭❬
    "    ❯❮
    "    ❱❰
    "}}}
    exe 'syn match '.a:ft.'FoldMarkers'
        \ . ' /'.a:cml_0_1.'\s*{'.'{{\d*\s*\ze\n/'
        \ . ' conceal'
        \ . ' cchar=❭'
        \ . ' contains='.a:ft.'CommentLeader'
        \ . ' contained'
        \ . ' containedin='.a:commentGroup.','
        \                  .a:ft.'CommentCodeBlock'

    exe 'syn match '.a:ft.'FoldMarkers'
        \ . ' /'.a:cml_0_1.'\s*}'.'}}\d*\s*\ze\n/'
        \ . ' conceal'
        \ . ' cchar=❬'
        \ . ' contains='.a:ft.'CommentLeader'
        \ . ' contained'
        \ . ' containedin='.a:commentGroup.','
        \                  .a:ft.'CommentCodeBlock'
endfu

fu! s:syn_mycustomgroups(ft) abort "{{{2
    let groups = copy(s:custom_groups)
    call map(groups, {i,v ->
        \ v[0] is# '@' ? '@' . a:ft . substitute(v, '@', '', '') : a:ft . v})
    let groups = join(groups, ',')
    exe 'syn cluster '.a:ft.'MyCustomGroups contains='.groups
endfu

