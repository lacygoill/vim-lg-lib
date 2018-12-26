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
        \ . '%sCommentBlockquote,'
        \ . '%sCommentBlockquoteBold,'
        \ . '%sCommentBlockquoteCodeSpan,'
        \ . '%sCommentBold,'
        \ . '%sCommentBoldItalic,'
        \ . '%sCommentCodeBlock,'
        \ . '%sCommentCodeSpan,'
        \ . '%sCommentIgnore,'
        \ . '%sCommentItalic,'
        \ . '%sCommentList,'
        \ . '%sCommentOption,'
        \ . '%sCommentOutput,'
        \ . '%sCommentPointer,'
        \ . '%sCommentTitle,'
        \ . '%sCommentTitleLeader,'
        \ . '%sFoldMarkers'
        \ ]
        \ + repeat([a:filetype], 17)
        \ )
endfu

fu! s:get_filetype() abort "{{{2
    let filetype = expand('<amatch>')
    if filetype is# 'snippets' | let filetype = 'snip' | endif
    return filetype
endfu

fu! lg#styled_comment#highlight() abort "{{{2
    let filetype = s:get_filetype()

    exe 'hi '     .filetype.'FoldMarkers term=bold cterm=bold gui=bold'

    exe 'hi link '.filetype.'CommentLeader              Comment'
    exe 'hi link '.filetype.'CommentOption              markdownOption'
    exe 'hi link '.filetype.'CommentList                markdownList'
    exe 'hi link '.filetype.'CommentPointer             markdownPointer'
    exe 'hi link '.filetype.'CommentTable               markdownTable'

    exe 'hi link '.filetype.'CommentTitle               PreProc'
    exe 'hi link '.filetype.'CommentOutput              PreProc'

    exe 'hi link '.filetype.'CommentItalic              CommentItalic'
    exe 'hi link '.filetype.'CommentBold                CommentBold'
    exe 'hi link '.filetype.'CommentBoldItalic          CommentBoldItalic'
    exe 'hi link '.filetype.'CommentCodeSpan            CommentCodeSpan'
    exe 'hi link '.filetype.'CommentCodeBlock           CommentCodeSpan'

    exe 'hi link '.filetype.'CommentBlockquote          markdownBlockquote'
    exe 'hi link '.filetype.'CommentBlockquoteLeader    Comment'
    exe 'hi link '.filetype.'CommentBlockquoteItalic    markdownBlockquoteItalic'
    exe 'hi link '.filetype.'CommentBlockquoteBold      markdownBlockquoteBold'
    exe 'hi link '.filetype.'CommentBlockquoteCodeSpan  markdownBlockquoteCodeSpan'
endfu

fu! lg#styled_comment#syntax() abort "{{{2
    " TODO: integrate most of the comments from this function into our notes

    " TODO: find a consistent order for the arguments of a region (and other items)
    " and stick to it (here and in the markdown syntax plugin)

    " TODO: Improve the performance by avoiding quantifiers inside lookaround.
    " Make some tests using `:syntime`.
    " If necessary,  replace regions  with matches, and  define a  custom syntax
    " group describing the comment leader to restore its color.

    " TODO: make  sure that for  each `matchgroup=xGroup`, `xGroup` is  a custom
    " group, that we can define in our colorscheme.
    " Never write something like `matchgroup=PreProc`.
    " `PreProc` is not a custom HG.
    " We want a single location from which we can change the highlighting of our
    " comments consistently.

    let filetype = s:get_filetype()

    " What does it do?{{{
    "
    " It defines  a cluster  containing all  the custom  syntax groups  that the
    " current function is going to define.
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
    " We need  an easy  way to tell  Vim that these  default groups  must *also*
    " exclude our custom groups.
    "}}}
    " How can this custom cluster be used?{{{
    "
    " When  a default  syntax plugin  uses the  arguments `contains=ALLBUT,...`,
    " clear it (`:syn clear ...`) and redefine it in `after/syntax/x.vim`.
    " Use the same original definition, with one change:
    " add `@xMyCustomGroups` after `contains=ALLBUT,...`.
    " }}}
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

    exe 'syn match '.filetype.'CommentLeader'
        \ . ' /^\s*'.cml_1.'/'
        \ . ' contained'
        \ . ' containedin='.filetype.'CommentPointer'

    "     some code block
    " Why a region?{{{
    "
    " I  want `xCommentCodeBlock`  to highlight  only  after 5  spaces from  the
    " comment leader (instead of complete lines).
    " It's less noisy.
    "}}}
    exe 'syn region '.filetype.'CommentCodeBlock'
        \ . ' matchgroup=Comment'
        \ . ' start=/^\s*'.cml_1.'     /'
        \ . ' matchgroup=NONE'
        \ . ' end=/$/'
        \ . ' keepend'
        \ . ' contained'
        \ . ' containedin='.commentGroup
        \ . ' oneline'

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
        \ . ' keepend'
        \ . ' concealends'
        \ . ' contained'
        \ . ' containedin='.commentGroup
        \ . ' oneline'

    " some *italic* comment
    exe 'syn region '.filetype.'CommentItalic'
        \ . ' matchgroup=Comment'
        \ . ' start=/\*\@1<!\*\*\@!/'
        \ . '   end=/\*\@1<!\*\*\@!/'
        \ . ' keepend'
        \ . ' concealends'
        \ . ' contained'
        \ . ' containedin='.commentGroup
        \ . ' oneline'

    " some **bold** comment
    exe 'syn region '.filetype.'CommentBold'
        \ . ' matchgroup=Comment'
        \ . ' start=/\*\*/'
        \ . '  end=/\*\*/'
        \ . ' keepend'
        \ . ' concealends'
        \ . ' contained'
        \ . ' containedin='.commentGroup
        \ . ' oneline'

    " some ***bold and italic*** comment
    exe 'syn region '.filetype.'CommentBoldItalic'
        \ . ' matchgroup=Comment'
        \ . ' start=/\*\*\*/'
        \ . '  end=/\*\*\*/'
        \ . ' keepend'
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
        \ . ' keepend'
        \ . ' concealends'
        \ . ' contained'
        \ . ' containedin='.filetype.'CommentBlockquote'
        \ . ' oneline'

    " > some `code span` in a quote
    exe 'syn region '.filetype.'CommentBlockquoteCodeSpan'
        \ . ' matchgroup=PreProc'
        \ . ' start=/`\@1<!``\@!/'
        \ . '   end=/`\@1<!``\@!/'
        \ . ' keepend'
        \ . ' concealends'
        \ . ' contained'
        \ . ' containedin='.filetype.'CommentBlockquote'
        \ . ' oneline'

    "     $ shell command
    "     output~
    " Why `\%(...\)\@<=` for these 2 statements?{{{
    "
    " It's required in the first statement because:
    "
    "    1. `xCommentOutput` is contained in `xCommentCodeBlock`
    "    2. `xCommentCodeBlock` is a region using `matchgroup=`
    "    3. `matchgroup=` prevents  a contained  item to  match where  `start` and
    "       `end` matched
    "
    " It's required in  the second statement because we don't  want to highlight
    " with `Ignore` *all* the output of a command, only the last tilde.
    "}}}
    " Why `18` in `\@18@<=`?{{{
    "
    " `xCommentOutput` has a negative impact on performance, probably because of
    " the positive lookbehind which contains a quantifier.
    "
    " MWE:
    "
    "    1. remove `18`
    "    2. totally unfold your vimrc
    "    3. run `:syn clear` and `:syn on`
    "    4. move at the bottom of the file, and press `C-u` until the beginning
    "    5. run `:syn off` and `:syn report`
    "
    " Limiting the backtracking to `18` improves the performance by a factor of ≈ `4`.
    "}}}
    " Are there cases where `18` will cause the syntax highlighting to break?{{{
    "
    " Yes.
    " If  the text  in the  output is more  than `18`  characters away  from the
    " beginning of the line.
    "
    " Currently, with `&sw = 4`, `18`  means that the syntax highlighting should
    " work when  the line  is not  indented, and when  it's indented  by 4  or 8
    " spaces.
    " That's 3 possible levels.
    "}}}
    " Is there a solution?{{{
    "
    " Try to use `&sw = 2`.
    " With this new value, you could  reduce `18` to `14` while still increasing
    " the supported  number of indentation levels  from 3 to 4,  which should be
    " enough for most comments.
    "}}}
    exe 'syn match '.filetype.'CommentOutput'
        \ . ' /\%(^ *'.cml_1.'     \)\@18<=.*\~$/'
        \ . ' contained'
        \ . ' containedin='.filetype.'CommentCodeBlock'
        \ . ' nextgroup='.filetype.'CommentIgnore'
    exe 'syn match '.filetype.'CommentIgnore'
        \ . ' /\%(^ *'.cml_1.'.*\)\@<=.$/'
        \ . ' contained'
        \ . ' containedin='.filetype.'CommentOutput'
        \ . ' conceal'

    " some `'option'`
    exe 'syn match '.filetype.'CommentOption'
        \ . ' /`\@1<=''.\{-}''`\@=/'
        \ . ' contained'
        \ . ' containedin='.filetype.'CommentCodeSpan'

    " not a pointer v
    " v
    "       v
    " This item must be defined *after* `xCommentCodeBlock`?{{{
    "
    " Otherwise its  highlighting would  fail when the  pointer is  located more
    " than 4 characters away from the comment leader.
    "}}}
    exe 'syn match '.filetype.'CommentPointer'
        \ . ' /^\s*'.cml_1.'\s*\%([v^✘✔]\+\s*\)\+$/'
        \ . ' contained'
        \ . ' containedin='.commentGroup

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
    exe 'syn region '.filetype.'CommentTable'
        \ . ' matchgroup=Comment'
        \ . ' start=/^\s*'.cml_1.'    [│─┌└├]\@=/'
        \ . ' matchgroup=Structure'
        \ . ' end=/$/'
        \ . ' keepend'
        \ . ' oneline'
        \ . ' contained'
        \ . ' containedin='.commentGroup

    " FIXME: the second item should be blue, and all comment leaders should be green
    " - some list item 1
    " - some list item 2
    " - some list item 3
    " TODO:  add support  for codespan,  italic, bold,  bold+italic, blockquote,
    " code block, ... inside list
    exe 'syn region '.filetype.'CommentList'
        \ . ' start=/^\s*'.cml_1.' \{,4\}\%([-*+•]\|\d\+\.\)\s\+\S/'
        \ . ' end=/^\s*'.cml_1.'\%(\s*\n\s*'.cml_1.'\s\=\S\)\@=\|^\s*\%('.cml_1.'\)\@!/'
        \ . ' keepend'
        \ . ' contained'
        \ . ' containedin='.commentGroup
        \ . ' contains='.filetype.'FoldMarkers,'.filetype.'CommentCodeBlock'
    " should we add `oneline`?

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
    exe 'syn match '.filetype.'FoldMarkers'
        \ . ' /'.cml_0_1.'\s*{'.'{{\d*\s*\ze\n/'
        \ . ' conceal'
        \ . ' cchar=❭'
        \ . ' contained'
        \ . ' containedin='.commentGroup.','.filetype.'CommentCodeBlock'
    exe 'syn match '.filetype.'FoldMarkers'
        \ . ' /'.cml_0_1.'\s*}'.'}}\d*\s*\ze\n/'
        \ . ' contained'
        \ . ' containedin='.commentGroup.','.filetype.'CommentCodeBlock'
        \ . ' conceal'
        \ . ' cchar=❬'

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

