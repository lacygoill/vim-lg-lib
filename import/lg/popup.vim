vim9script noclear

if exists('loaded') | finish | endif
var loaded = true

# `#create()` raises errors!{{{
#
# Don't use `minwidth`, `maxwidth`, `minheight`, `maxheight`.
# Just use `width` and `height`.
#}}}
# I have another issue with one of these functions!{{{
#
# Switch `DEBUG` to 1 in this file.
# Reproduce your issue, then read the logfile.
#
# Check whether the code in the logfile looks ok.
# If it does, the issue may be due to a Vim bug.
# Otherwise, if  some line seems wrong,  check out your source  code; start your
# search by pressing `C-w F` on the previous commented line.
#}}}

# TODO: When you'll need to log another feature (other than the popup window), move `Log()` in `autoload/lg.vim`.{{{
#
# You'll need to use a different expression for each feature; e.g.:
#
#     const DEBUG: dict<bool> = {popup: false, other feature: false}
#     const LOGFILE: dict<string> = {popup-nvim: '/tmp/...', popup-vim: '/tmp/...', other-feature: '/tmp/...'}
#
#     ...
#                                   new argument
#                                   v-----v
#     def Log(msg, funcname, slnum, feature)
#         if !DEBUG[feature]
#             return
#         endif
#         ...
#         writefile([time, source, msg], LOGFILE[feature], 'a')
#         ...
#}}}

# Init {{{1

const DEBUG: bool = false
const LOGFILE: string = '/tmp/.vim-popup-window.log.vim'
const MAX_ZINDEX: number = 32'000

# Interface {{{1
export def Popup_create(what: any, opts: dict<any>): list<number> #{{{2
# TODO(Vim9): `what: any` → `what: number|string|list<string>`
    var has_border: bool = opts->has_key('border')
    var is_term: bool = opts->has_key('term') ? remove(opts, 'term') : false
    if !has_border && !is_term
        return Basic(what, opts)
    elseif has_border && !is_term
        return Border(what, opts)
    elseif is_term
        return Terminal(what, opts)
    endif
    return []
enddef

export def Popup_notification( #{{{2
    # TODO(Vim9): `what: any` → `what: number|string|list<string>`
    what: any,
    arg_opts: dict<any> = {}
): list<number>

    var lines: list<string> = GetLines(what)
    var n_opts: dict<any> = GetNotificationOpts(lines)
    var opts: dict<any> = extendnew(arg_opts, n_opts, 'keep')
    return Popup_create(lines, opts)
enddef
#}}}1
# Core {{{1
def Basic(arg_what: any, opts: dict<any>): list<number> #{{{2
# TODO(Vim9): `arg_what: any` → `arg_what: number|string|list<string>`
    var funcname: string = expand('<stack>')->matchstr('.*\.\.\zs<SNR>\w\+')
    # This serves 2 purposes:{{{
    #
    #    - it lets us use a multiline string (otherwise, newlines would be translated into NULs)
    #    - it prevents an error later:
    #
    #         var cmd: string = printf('var winid = popup_create(%s, %s)', what, opts)
    #         " if `what` is the string 'TEST', the surrounding quotes will be removed by `printf()`:
    #         E121: Undefined variable: TEST˜
    #}}}
    var what: any = arg_what
    if typename(arg_what) == 'string'
        what = split(arg_what, '\n')
    endif
    extend(opts, {zindex: MAX_ZINDEX}, 'keep')

    # Vim doesn't recognize the 'width' and 'height' keys.
    # We really need the `max` keys.{{{
    #
    # For  example,  without the  `maxheight`  key,  the window's  height  would
    # increase when executing a shell command with a long output (e.g. `$ infocmp -1x`).
    #
    # Note that if the function uses `border: []`, then we don't need the `max` keys.
    # However, there's  no guarantee that the  function will use a  border; e.g.
    # `border` could have been set with the value `[0, 0, 0, 0]`.
    #
    # Besides, we set  the `max` keys to be consistent  with popup windows where
    # we don't use a border.
    #}}}
    extend(opts, {
        minwidth: opts.width,
        maxwidth: opts.width,
        minheight: opts.height,
        maxheight: opts.height,
    })
    remove(opts, 'width') | remove(opts, 'height')
    var cmd: string = printf('var winid = popup_create(%s, %s)', what, opts)
    Log(cmd, funcname, expand('<slnum>')->str2nr())
    var winid: number = popup_create(what, opts)

    # Don't reset the topline of the popup on the next screen redraw.{{{
    #
    # Useful when you've installed key bindings to scroll in the popup and don't
    # want Vim to cancel your scrolling on the next redraw.
    #
    # The value `0` is documented at `:h popup_create-arguments /firstline`:
    #
    #    > firstline       ...
    #    >                 Set to zero to leave the position as set by commands.
    #}}}
    cmd = printf('popup_setoptions(%d, {firstline: 0})', winid)
    Log(cmd, funcname, expand('<slnum>')->str2nr())
    popup_setoptions(winid, {firstline: 0})
    return [winbufnr(winid), winid]
enddef

def Border(what: any, opts: dict<any>): list<number> #{{{2
# TODO(Vim9): `what: any` → `what: number|string|list<string>`
    # reset geometry so that the inner text fits inside the border
    # Why these particular numbers in the padding list?{{{
    #
    # I like to add  one empty column between the start/end of  the text and the
    # left/right borders.  It's more aesthetically pleasing.
    #
    # OTOH, I  don't like adding an  empty line above/below the  text.  It takes
    # too much space, which is more precious vertically than horizontally.
    #}}}
    extend(opts, {padding: [0, 1, 0, 1]}, 'keep')
    extend(opts, {
        # to get the same position as in Nvim
        col: opts.col - 1,
        width: opts.width,
        height: opts.height,
    })
    # Vim expects the 'borderhighlight' key to be a list.  We want a string; do the conversion.
    opts.borderhighlight = [get(opts, 'borderhighlight', '')]

    # open final window
    SetBorderchars(opts)
    return Basic(what, opts)
enddef

def Terminal(what: any, opts: dict<any>): list<number> #{{{2
# TODO(Vim9): `what: any` → `what: number|string|list<string>`
    var funcname: string = expand('<stack>')
        ->matchstr('\.\.\zs.*\ze\[\d\+\]\.\.$')
    var bufnr: number
    # If `what` is the number of a terminal buffer, don't create yet another one.{{{
    #
    # Just use `what`.
    # This is useful, in particular, when toggling a popup terminal.
    #}}}
    if IsTerminalBuffer(what)
        bufnr = what
    else
        var cmd: string = 'var bufnr = term_start(&shell, {'
            .. "hidden: true, "
            .. "term_finish: 'close', "
            .. "term_kill: 'hup'"
            .. '})'
        Log(cmd, funcname, expand('<slnum>')->str2nr())
        bufnr = term_start(&shell, {hidden: true, term_finish: 'close', term_kill: 'hup'})
    endif
    # in Terminal-Normal mode, don't highlight empty cells with `Pmenu` (same thing for padding cells)
    opts.highlight = 'Normal'
    # make sure a border is drawn even if the `border` key was not set
    opts.border = get(opts, 'border', [])
    var info: list<number> = Border(bufnr, opts)
    FireTerminalEvents()
    return info
enddef
#}}}1
# Util {{{1
def FireTerminalEvents() #{{{2
    # Install our custom terminal settings as soon as the terminal buffer is displayed in a window.{{{
    #
    # Useful, for example,  to get our `Esc Esc` key  binding, and for `M-p`
    # to work (i.e. recall latest command starting with current prefix).
    #}}}
    if exists('#TerminalWinOpen') | do <nomodeline> TerminalWinOpen | endif
    if exists('#User#TermEnter') | do <nomodeline> User TermEnter | endif
enddef

def GetBorderchars(): list<string> #{{{2
    return ['─', '│', '─', '│', '┌', '┐', '┘', '└']
enddef

def SetBorderchars(opts: dict<any>) #{{{2
    extend(opts, {borderchars: GetBorderchars()}, 'keep')
enddef

def GetLines(what: any): list<string> #{{{2
# TODO(Vim9): `what: any` → `what: number|string|list<string>`
    var lines: list<string>
    if typename(what) =~ '^list'
        lines = what
    elseif typename(what) == 'string'
        lines = split(what, '\n')
    elseif typename(what) == 'number'
        lines = getbufline(what, 1, '$')
    endif
    return lines
enddef

def GetNotificationOpts(lines: list<string>): dict<any> #{{{2
    var longest: number = GetLongestWidth(lines)
    var width: number
    var height: number
    [width, height] = [longest, len(lines)]
    var opts: dict<any> = {
        line: 2,
        col: &columns,
        width: width,
        height: height,
        border: [],
        highlight: 'WarningMsg',
        focusable: false,
        pos: 'topright',
        time: 3'000,
        tabpage: -1,
        zindex: 300,
    }
    return opts
enddef

def GetLongestWidth(lines: list<string>): number
    return lines
        ->mapnew((_, v: string): number => strcharlen(v))
        ->max()
enddef

def IsTerminalBuffer(n: number): bool #{{{2
    return typename(n) == 'number' && n > 0 && getbufvar(n, '&buftype', '') == 'terminal'
enddef

def Log( #{{{2
    msg: string,
    funcname: string,
    slnum: number
)
    if !DEBUG
        return
    endif
    var time: string = '" ' .. strftime('%H:%M:%S')
    var sourcefile: string = execute('verb fu ' .. funcname)->split('\n')[1]
    var matchlist: list<string> = matchlist(sourcefile,
        '^\s*Last set from \(.*\)\s\+line \(\d\+\)')
    sourcefile = matchlist[1]
    var lnum: number = matchlist[2]->str2nr()
    var source: string = '" ' .. sourcefile .. ':' .. (lnum + slnum)
    writefile([time, source, msg], LOGFILE, 'a')
enddef

