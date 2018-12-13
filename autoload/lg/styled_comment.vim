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
    exe call('printf', [
        \   'syn cluster %sMyCustomGroups contains='
        \ . '%sFoldMarkers,'
        \ . '%sCommentCodeSpan,'
        \ . '%sCommentEmphasis,'
        \ . '%sCommentStrong,'
        \ . '%sCommentCodeBlock,'
        \ . '%sCommentBlockQuote,'
        \ . '%sCommentTitle,'
        \ . '%sCommentTitleLeader'
        \ ]
        \ + repeat([a:filetype], 9)
        \ )
endfu

fu! lg#styled_comment#syntax() abort "{{{2
    " Purpose: define the following syntax groups{{{
    "
    "     xFoldMarkers
    "
    "     xCommentCodeSpan
    "     xCommentEmphasis
    "     xCommentStrong
    "     xCommentCodeBlock
    "     xCommentBlockQuote
    "     xCommentTitle
    "     xCommentTitleLeader
    "}}}

    " TODO: integrate most of the comments from this function into our notes
    let filetype = expand('<amatch>')

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
    " the real number of character inside the comment leader.
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
    exe 'syn match '.filetype.'FoldMarkers /'.cml_0_1.'\s*{'.'{{\d*\s*\ze\n/ conceal cchar=❭ contained containedin=vimComment,vimLineComment'
    exe 'syn match '.filetype.'FoldMarkers /'.cml_0_1.'\s*}'.'}}\d*\s*\ze\n/ conceal cchar=❬ contained containedin=vimComment,vimLineComment'

    let group_name = filetype . (filetype is# 'vim' ? 'LineComment' : 'Comment')
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
    "     CommentEmphasis
    "     CommentStrong
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
    " But, isn't `containedin=` enough?{{{
    "
    " No.
    "
    " `containedin=Foo` doesn't mean:
    "
    " >    the item MUST be inside `Foo`
    "
    " but:
    "
    " >    the item IS ALLOWED to be inside `Foo`
    "}}}
    exe 'syn region '.filetype.'CommentCodeSpan matchgroup=Comment start=/`\@<!``\@!/ end=/`\@<!``\@!/ oneline concealends contained containedin='.group_name
    exe 'syn region '.filetype.'CommentEmphasis matchgroup=Comment start=/\*\@<!\*\*\@!/ end=/\*\@<!\*\*\@!/ oneline concealends contained containedin='.group_name
    exe 'syn region '.filetype.'CommentStrong matchgroup=Comment start=/\*\*/ end=/\*\*/ oneline concealends contained containedin='.group_name

    " TODO: `containedin=ALL`: should we be more specific?
    " Update:
    " I don't know, but a blockquote may be inside a Vim function.
    " So, you need  to tell Vim that `vimCommentBlockQuote` may  be contained in
    " `vimFuncBody`, otherwise  you won't  have the italic  style even  when you
    " start a comment with `>` in a Vim comment.
    " And who knows what others syntax groups a blockquote could be contained in...

    " Why `\%(..\)\@<=`?{{{
    "
    " I want `xCommentCodeBlock` to highlight  only from the comment leader (and
    " not complete lines).
    " It's less noisy.
    "}}}
    " Warning: Do *not* use `\zs` instead of `\%(...\)\@<=`!{{{
    "
    " It would sometimes break `xCommentCodeBlock`.
    " MWE:
    "     $ echo ' #    codeblock' >/tmp/awk.awk
    "             ^
    "             ✘ indentation breaks syntax
    "
    "     $ vim /tmp/awk.awk
    "
    " The text `#    codeblock` is not properly highlighted.
    "
    " Why?
    " The beginning of a nested item must be inside the containing item.
    " From `:h syn-contains`:
    "
    " >    These groups will be allowed to begin **inside** the item...
    "
    " In particular,  a nested item can  *not* begin before the  containing item
    " has begun.
    "
    " If you use `\zs`, `xCommentCodeBlock`  will start right from the beginning
    " of the line, because the regex starts with the anchor `^`.
    " Yes, `\zs` doesn't change the start of the item.
    "
    " But `xCommentCodeBlock` is supposed to be contained in `xComment`.
    " OTOH, `xComment` may sometimes begin *after* the beginning of the line.
    " Example:
    "
    "     syn match awkComment "#.*" contains=@Spell,awkTodo
    "
    " Here, `awkComment` doesn't start at the  beginning of the line, but at the
    " comment leader.
    " As  a  result, if  your  comment  is indented  (i.e.  there's  at least  1
    " space between  the beginning  of the  line and  the comment  leader), then
    " `xCommentCodeBlock` will start *before* `xComment`.
    "}}}
    exe 'syn match '.filetype.'CommentCodeBlock /\%(^\s*\)\@<='.cml_1.'\s\{4}[^•│└┌─]*$/ contained containedin=ALL'
    " define blockquote
    " Why do you allow `xCommentStrong` to be contained in `xCommentBlockQuote`?{{{
    "
    " In a  markdown buffer,  we can make  some text be  displayed in  bold even
    " inside a blockquote.
    " To stay  consistent, we should be able  to do the same in  the comments of
    " other filetypes.
    "}}}
    exe 'syn match '.filetype.'CommentBlockQuote /^\s*'.cml_1.'\s*>.*/ contained containedin=ALL contains='.filetype.'CommentStrong'
    " conceal the leading `>`
    exe 'syn match '.filetype.'CommentBlockQuote /\%(^\s*'.cml_1.'\s*\)\@<=>/ contained containedin='.filetype.'CommentBlockQuote conceal'

    if filetype isnot# 'vim'
        " TODO: Explain how the code works.
        exe 'syn match '.filetype.'CommentTitle /'.cml_1.'\s*\u\w*\(\s\+\u\w*\)*:/hs=s+'.nr.' contained contains='.filetype.'CommentTitleLeader,'.filetype.'Todo'
        exe 'syn match '.filetype.'CommentTitleLeader /'.cml_1.'\s\+/ms=s+'.nr.' contained'
    endif
endfu

fu! lg#styled_comment#highlight() abort "{{{2
    let filetype = expand('<amatch>')
    exe 'hi link  '.filetype.'CommentStrong     CommentStrong'
    exe 'hi link  '.filetype.'CommentEmphasis   CommentEmphasis'
    exe 'hi link  '.filetype.'CommentCodeSpan   CommentCodeSpan'
    exe 'hi link  '.filetype.'CommentCodeBlock  CommentCodeSpan'
    exe 'hi link  '.filetype.'CommentBlockQuote CommentBlockQuote'
    exe 'hi link  '.filetype.'CommentTitle      PreProc'
endfu

