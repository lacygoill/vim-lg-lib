" filetype plugin {{{1
fu! lg#styled_comment#fold() abort "{{{2
    let filetype = expand('<amatch>')
    exe 'augroup my_'.filetype
        au! *            <buffer>
        au  BufWinEnter  <buffer>  setl fdm=marker
                               \ | setl fdt=fold#fdt#get()
                               \ | setl cocu=nc
                               \ | setl cole=3
    augroup END
endfu

fu! lg#styled_comment#undo_ftplugin() abort "{{{2
    let filetype = expand('<amatch>')
    let b:undo_ftplugin = get(b:, 'undo_ftplugin', '')
        \ . (empty(get(b:, 'undo_ftplugin', '')) ? '' : '|')
        \ . "
        \   setl cocu< cole< fdm< fdt<
        \ | exe 'au! my_".filetype." * <buffer>'
        \ "
endfu
" }}}1
" syntax plugin {{{1
fu! s:define_cluster(filetype) abort "{{{2
    " Why not `:call call()`?{{{
    "
    " It would be equivalent to:
    "
    "     call printf(...)
    "
    " Which would do nothing, except printing a string.
    " We don't want to print a string.
    " We want to execute its contents.
    "}}}
    exe call('printf', [
        \   'syn cluster %sMyCustomGroups contains='
        \ . '%sFoldMarkers,'
        \ . '%sCommentCodeSpan,'
        \ . '%sCommentItalic,'
        \ . '%sCommentBold,'
        \ . '%sCommentCodeBlock,'
        \ . '%sCommentBlockquote,'
        \ . '%sCommentTitle,'
        \ . '%sCommentTitleLeader'
        \ ]
        \ + repeat([a:filetype], 9)
        \ )
endfu

fu! s:get_filetype() abort "{{{2
    let filetype = expand('<amatch>')
    if filetype is# 'snippets' | let filetype = 'snip' | endif
    return filetype
endfu

fu! lg#styled_comment#highlight() abort "{{{2
    let filetype = s:get_filetype()

    exe 'hi link  '.filetype.'CommentTitle               PreProc'

    exe 'hi link  '.filetype.'CommentItalic              CommentItalic'
    exe 'hi link  '.filetype.'CommentBold                CommentBold'
    exe 'hi link  '.filetype.'CommentBoldItalic          CommentBoldItalic'
    exe 'hi link  '.filetype.'CommentCodeSpan            CommentCodeSpan'
    exe 'hi link  '.filetype.'CommentCodeBlock           CommentCodeSpan'

    exe 'hi link  '.filetype.'CommentBlockquote          markdownBlockquote'
    exe 'hi link  '.filetype.'CommentBlockquoteLeader    Comment'
    exe 'hi link  '.filetype.'CommentBlockquoteItalic    markdownBlockquoteItalic'
    exe 'hi link  '.filetype.'CommentBlockquoteBold      markdownBlockquoteBold'
    exe 'hi link  '.filetype.'CommentBlockquoteCodeSpan  markdownBlockquoteCodeSpan'

    exe 'hi link  '.filetype.'CommentList                markdownList'

    exe 'hi '      .filetype.'FoldMarkers term=bold cterm=bold gui=bold'
endfu

fu! lg#styled_comment#syntax() abort "{{{2
    " TODO: Update the lists of the syntax groups that this function defines.
    " Purpose: define the following syntax groups{{{
    "
    "     xFoldMarkers
    "
    "     xCommentCodeSpan
    "     xCommentItalic
    "     xCommentBold
    "     xCommentCodeBlock
    "     xCommentBlockquote
    "     xCommentTitle
    "     xCommentTitleLeader
    "}}}

    " TODO: integrate most of the comments from this function into our notes
    let filetype = s:get_filetype()

    call s:define_cluster(filetype)

    let cml = filetype is# 'gitconfig'
        \ ?     '#'
        \ :     matchstr(get(split(&l:cms, '%s'), 0, ''), '\S*')
    " What do you need this `nr` for?{{{
    "
    " For offsets when defining the syntax groups:
    "
    "     • xxxCommentTitle
    "     • xxxCommentTitleLeader
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
    let cml = escape(cml, '/\')
    let cml_1 = '\V'.cml.'\m'
    let cml_0_1 = '\V\%('.cml.'\)\=\m'

    let commentGroup = filetype . 'Comment' . (filetype is# 'vim' ? ',vimLineComment' : '')

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
    " ❭❬
    " ❯❮
    " ❱❰
    exe 'syn match '.filetype.'FoldMarkers'
        \ . ' /'.cml_0_1.'\s*{'.'{{\d*\s*\ze\n/'
        \ . ' conceal'
        \ . ' cchar=❭'
        \ . ' contained'
        \ . ' containedin='.commentGroup
    exe 'syn match '.filetype.'FoldMarkers'
        \ . ' /'.cml_0_1.'\s*}'.'}}\d*\s*\ze\n/'
        \ . ' contained'
        \ . ' containedin='.commentGroup
        \ . ' conceal'
        \ . ' cchar=❬'

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
    exe 'syn region '.filetype.'CommentCodeSpan'
        \ . ' matchgroup=Comment'
        \ . ' start=/`\@1<!``\@!/'
        \ . '   end=/`\@1<!``\@!/'
        \ . ' concealends'
        \ . ' contained'
        \ . ' containedin='.commentGroup
        \ . ' oneline'

    " some *italic* comment
    exe 'syn region '.filetype.'CommentItalic'
        \ . ' matchgroup=Comment'
        \ . ' start=/\*\@1<!\*\*\@!/'
        \ . '   end=/\*\@1<!\*\*\@!/'
        \ . ' concealends'
        \ . ' contained'
        \ . ' containedin='.commentGroup
        \ . ' oneline'

    " some **bold** comment
    exe 'syn region '.filetype.'CommentBold'
        \ . ' matchgroup=Comment'
        \ . ' start=/\*\*/'
        \ . '  end=/\*\*/'
        \ . ' concealends'
        \ . ' contained'
        \ . ' containedin='.commentGroup
        \ . ' oneline'

    " some ***bold and italic*** comment
    exe 'syn region '.filetype.'CommentBoldItalic'
        \ . ' matchgroup=Comment'
        \ . ' start=/\*\*\*/'
        \ . '  end=/\*\*\*/'
        \ . ' concealends'
        \ . ' contained'
        \ . ' containedin='.commentGroup
        \ . ' oneline'

    " > some quote
    " <not> a quote
    " Why do you allow `xCommentBold` to be contained in `xCommentBlockquote`?{{{
    "
    " In a  markdown buffer,  we can make  some text be  displayed in  bold even
    " inside a blockquote.
    " To stay  consistent, we should be able  to do the same in  the comments of
    " other filetypes.
    "}}}
    exe 'syn match '.filetype.'CommentBlockquote /^\s*'.cml_1.'\s*>.*/'
        \ . ' contained'
        \ . ' containedin='.commentGroup
        \ . ' contains='.filetype.'CommentBlockquoteLeader,'.filetype.'CommentBlockquoteConceal'
        \ . ' contains='.filetype.'CommentBold'
        \ . ' oneline'
    exe 'syn match '.filetype.'CommentBlockquoteConceal'
        \ . ' /\%(^\s*'.cml_1.'\s*\)\@<=>\s/'
        \ . ' contained'
        \ . ' conceal'
    exe 'syn match '.filetype.'CommentBlockquoteLeader'
        \ . ' /^\s*'.cml_1.'/'
        \ . ' contained'

    " > some **bold** quote
    exe 'syn region '.filetype.'CommentBlockquoteBold'
        \ . ' matchgroup=PreProc'
        \ . ' start=/\*\*/'
        \ . '   end=/\*\*/'
        \ . ' concealends'
        \ . ' contained'
        \ . ' containedin='.filetype.'CommentBlockquote'
        \ . ' oneline'

    " > some `code span` in a quote
    exe 'syn region '.filetype.'CommentBlockquoteCodeSpan'
        \ . ' matchgroup=PreProc'
        \ . ' start=/`\@1<!``\@!/'
        \ . '   end=/`\@1<!``\@!/'
        \ . ' concealends'
        \ . ' contained'
        \ . ' containedin='.filetype.'CommentBlockquote'
        \ . ' oneline'

    "     some codeblock
    " Why a region?{{{
    "
    " I  want `xCommentCodeBlock`  to highlight  only  after 5  spaces from  the
    " comment leader (instead of complete lines).
    " It's less noisy.
    "}}}
    exe 'syn region '.filetype.'CommentCodeBlock'
        \ . ' matchgroup=Comment'
        \ . ' start=/^\s*'.cml_1.'\s\{5}/'
        \ . ' matchgroup=NONE'
        \ . ' end=/$/'
        \ . ' containedin='.commentGroup

    " FIXME: the second item should be blue, and all comment leaders should be green
    " - some list item 1
    " - some list item 2
    " - some list item 3
    " TODO:  add support  for codespan,  italic, bold,  bold+italic, blockquote,
    " codeblock, ... inside list
    exe 'syn region '.filetype.'CommentList'
        \ . ' start=/^\s*'.cml_1.' \{,4\}\%([-*+•]\|\d\+\.\)\s\+\S/'
        \ . ' end=/^\s*'.cml_1.'\%(\s*\n\s*'.cml_1.'\s\=\S\)\@=\|^\s*\%('.cml_1.'\)\@!/'
        \ . ' contained'
        \ . ' containedin='.commentGroup
        \ . ' contains='.filetype.'FoldMarkers,'.filetype.'CommentCodeBlock'

    "     ^ \{,3\}\%([-*+•]\|\d\+\.\)\s\+\S
    "     \_.\{-}
    "     \n\s*\n \{,2}\%([^-*+• \t]\|\%$\)\@=
    "     contained contains=markdownListItalic,markdownListBold,markdownListBoldItalic,markdownListCodeSpan

    if filetype isnot# 'vim'
        " TODO: Explain how the code works.
        exe 'syn match '.filetype.'CommentTitle'
            \ . ' /'.cml_1.'\s*\u\w*\%(\s\+\u\w*\)*:/hs=s+'.nr
            \ . ' contained'
            \ . ' contains='.filetype.'CommentTitleLeader,'.filetype.'Todo'
        exe 'syn match '.filetype.'CommentTitleLeader'
            \ . ' /'.cml_1.'\s\+/ms=s+'.nr
            \ . ' contained'
    endif

    " TODO: highlight commented urls (like in markdown)?
    "
    "     markdownLinkText xxx matchgroup=markdownLinkTextDelimiter
    "                          start=/!\=\[\%(\_[^]]*]\%( \=[[(]\)\)\@=/
    "                          end=/\]\%( \=[[(]\)\@=/
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
    "
    " TODO: highlight bullets in lists with `Repeat`.
    " Or highlight lists as a whole (with text)?
    "
    " TODO:
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
endfu

