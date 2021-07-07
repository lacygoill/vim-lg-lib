vim9script noclear

if exists('loaded') | finish | endif
var loaded = true

# Init {{{1

# Should support commands like `tldr(1)` and `trans(1)`:{{{
#
#     $ tldr tldr | vipe
#     $ trans word tldr | vipe
#}}}
# Why do you set the `gui`/`guifg` attributes?  We can only pipe the output of a shell command to Vim in the terminal...{{{
#
# Yes, but if `'termguicolors'` is set, Vim uses `guifg` instead of `ctermfg`.
#}}}

# TODO: Get those sequences programmatically via `tput(1)`.{{{
#
# Problem: I can't find some of them in `$ infocmp -1x`.
#
# I don't know their name:
#
#    - C-o
#    - CSI 22m
#
# I think they are hard-coded in the program which produce them.
# For example,  if you grep  the pattern `\[22`  in the codebase  of `trans(1)`,
# you'll find this:
#
#     AnsiCode["no bold"] = "\33[22m" # SGR code 21 (bold off) not widely supported
#}}}
# CSI 1m = bold (bold)
# CSI 3m = italicized (sitm)
# CSI 4m = underlined (smul)
# CSI 22m = normal (???)
# CSI 23m = not italicized (ritm)
# CSI 24m = not underlined (rmul)
# CSI 32m = green (setaf 2)
# C-o     = ??? (???)

const ATTR: dict<dict<string>> = {
    trans_bold: {
        start: "\<Esc>\[1m",
        end: "\<Esc>\[22m",
        highlight: 'term=bold cterm=bold gui=bold',
    },

    trans_boldunderlined: {
        start: "\<Esc>\[4m\<Esc>\[1m",
        end: "\<Esc>\[22m\<Esc>\[24m",
        highlight: 'term=bold,underline cterm=bold,underline gui=bold,underline',
    },

    tldr_boldgreen: {
        start: "\<Esc>\[32m\<Esc>\[1m",
        end: "\<Esc>\[m\%x0f",
        highlight: 'term=bold cterm=bold gui=bold ctermfg=green guifg=#198844',
    },

    tldr_italic: {
        start: "\<Esc>\[3m",
        end: "\<Esc>\[m\%x0f",
        highlight: 'term=italic cterm=italic gui=italic',
    },

    tldr_bold: {
        start: "\<Esc>\[1m",
        end: "\<Esc>\[m\%x0f",
        highlight: 'term=bold cterm=bold gui=bold',
    },
}

def Ansi() #{{{1
    if search("\<Esc>", 'cn') == 0
        return
    endif
    var view: dict<number> = winsaveview()

    # Why do you use text properties and not regex-based syntax highlighting?{{{
    #
    # Using text properties lets us remove the ansi codes.
    # This way, if we yank some line, we don't copy them.
    #}}}
    #   How would I get the same highlighting with syntax rules?{{{
    #
    # For the bold and bold+underlined attributes:
    #
    #     syntax region ansiBold matchgroup=Normal start=/\e\[1m/ end=/\e\[22m/ concealends oneline
    #     syntax region ansiBoldUnderlined matchgroup=Normal start=/\e\[4m\e\[1m/ end=/\e\[22m\e\[24m/ concealends oneline
    #     &l:conceallevel = 3
    #     &l:concealcursor = 'nc'
    #
    # Do not remove `oneline`.
    #
    # It would sometimes highlight text while it shouldn't.
    # E.g.:
    #
    #     $ env | vipe
    #
    # In this example, the issue comes from some environment variables which
    # contain escape sequences (`FINGERS_...`).
    #
    # Besides, I think  that most of the time, programs  which output escape
    # sequences do it only for a short text on a single line...
    #}}}
    var bufnr: number = bufnr('%')
    var attr: string
    var props: dict<string>
    for item: list<any> in items(ATTR)
        [attr, props] = item
        execute 'highlight ansi_' .. attr .. ' ' .. props.highlight
        cursor(1, 1)
        var flags: string = 'cW'
        prop_type_add('ansi_' .. attr, {highlight: 'ansi_' .. attr, bufnr: bufnr, combine: false})
        while search(props.start, flags) > 0 && search(props.end, 'n') > 0
            flags = 'W'
            prop_add(line('.'), col('.'), {
                length: searchpos(props.end .. '\zs', 'cn')[1] - col('.'),
                type: 'ansi_' .. attr,
            })
        endwhile
    endfor

    var clean_this: string = '\C\e\[\d*m\|[[:cntrl:]]'
    execute 'silent keepjumps keeppatterns lockmarks :% substitute/' .. clean_this .. '//ge'
    # Don't save the buffer.{{{
    #
    # It's useful to keep the file as it is, in case we want to send it to a Vim
    # server, and re-highlight the ansi escape codes in this other Vim instance.
    #}}}
    &l:modified = false
    winrestview(view)
enddef

Ansi()
