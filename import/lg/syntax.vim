vim9script

# Interface {{{1

# Purpose:{{{
#
# Derive a  new syntax group  (`to`) from  an existing one  (`from`), overriding
# some attributes (`newAttributes`).
#}}}
# Usage Examples:{{{
#
#     # create `CommentUnderlined` from `Comment`; override the `term`, `cterm`, and `gui` attributes
#
#         Derive('CommentUnderlined', 'Comment', 'term=underline cterm=underline gui=underline')
#
#     # create `PopupSign` from `WarningMsg`; override the `guibg` or `ctermbg` attribute,
#     # using the colors of the `Normal` HG
#
#         Derive('PopupSign', 'WarningMsg', {'bg': 'Normal'})
#}}}

export def Derive(to: string, from: string, newAttributes: any) #{{{2
# TODO(Vim9): `newAttributes: any` → `newAttributes: string|dict<string>`
    let originalDefinition = Getdef(from)
    let originalGroup: string
    # if the `from` syntax group is linked to another group, we need to resolve the link
    if originalDefinition =~# ' links to \S\+$'
        # Why the `while` loop?{{{
        #
        # Well, we don't know how many links there are; there may be more than one.
        # That is, the  `from` syntax group could be linked  to `A`, which could
        # be linked to `B`, ...
        #}}}
        let g = 0 | while originalDefinition =~# ' links to \S\+$' && g < 9 | g += 1
            let link = matchstr(originalDefinition, ' links to \zs\S\+$')
            originalDefinition = Getdef(link)
            originalGroup = link
        endwhile
    else
        originalGroup = from
    endif
    let pat = '^' .. originalGroup .. '\|xxx'
    let Rep = {m -> m[0] == originalGroup ? to : ''}
    let _newAttributes = Getattr(newAttributes)
    exe 'hi '
        .. substitute(originalDefinition, pat, Rep, 'g')
        .. ' ' .. _newAttributes
enddef
#}}}1
# Core {{{1
def Getdef(hg: string): string #{{{2
    # Why `split('\n')->filter(...)`?{{{
    #
    # The output of `:hi ExistingHG`  can contain noise in certain circumstances
    # (e.g. `-V15/tmp/log`, `-D`, `$ sudo`...).
    # }}}
    return execute('hi ' .. hg)
        ->split('\n')
        ->filter({_, v -> v =~# '^' .. hg })[0]
enddef

def Getattr(attr: any): string #{{{2
# TODO(Vim9): `attr: any` → `attr: string|dict<string>`
    if type(attr) == v:t_string
        return attr
    elseif type(attr) == v:t_dict
        let gui = has('gui_running') || &tgc
        let mode = gui ? 'gui' : 'cterm'
        let _attr: string
        let hg: string
        [_attr, hg] = items(attr)[0]
        let code = hlID(hg)
            ->synIDtrans()
            ->synIDattr(_attr, mode)
        if code =~# '^' .. (gui ? '#\x\+' : '\d\+') .. '$'
            return mode .. _attr .. '=' .. code
        endif
    endif
    return ''
enddef

