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

export def Derive(to: string, from: string, newAttributes: any, ...l: any) #{{{2
# TODO(Vim9): `newAttributes: any` → `newAttributes: string|dict<string>`
    var originalDefinition = Getdef(from)
    var originalGroup: string
    # if the `from` syntax group is linked to another group, we need to resolve the link
    if originalDefinition =~# ' links to \S\+$'
        # Why the `while` loop?{{{
        #
        # Well, we don't know how many links there are; there may be more than one.
        # That is, the  `from` syntax group could be linked  to `A`, which could
        # be linked to `B`, ...
        #}}}
        var g = 0 | while originalDefinition =~# ' links to \S\+$' && g < 9 | g += 1
            var link = matchstr(originalDefinition, ' links to \zs\S\+$')
            originalDefinition = Getdef(link)
            originalGroup = link
        endwhile
    else
        originalGroup = from
    endif
    var pat = '^' .. originalGroup .. '\|xxx'
    var Rep = {m -> m[0] == originalGroup ? to : ''}
    var _newAttributes = Getattr(newAttributes)
    exe 'hi '
        .. substitute(originalDefinition, pat, Rep, 'g')
        .. ' ' .. _newAttributes

    # We want our derived HG to persist even after we change the color scheme at runtime.{{{
    #
    # Indeed, all  color schemes run `:hi  clear`, which might clear  our custom
    # HG.  So, we need to save some information to reset it when needed.
    #}}}
    #   Ok, but why not saving the `:hi ...` command directly?{{{
    #
    # If we change the color scheme, we want to *re*-derive the HG.
    # For example, suppose we've run:
    #
    #     call s:Derive('Ulti', 'Visual', 'term=bold cterm=bold gui=bold')
    #
    # `Visual`  doesn't  have the  same  attributes  from  one color  scheme  to
    # another.  The next time we change the  color scheme, we can't just run the
    # exact same command as  we did for the previous one.   We need to re-invoke
    # `Derive()` with the same arguments.
    #}}}
    var hg = {to: to, from: from, new: newAttributes}
    if index(derived_hgs, hg) == -1
        derived_hgs += [hg]
    endif
enddef

# We   can't   write   `list<dict<string>>`,   because  we   need   to   declare
# `newAttributes` with the type `any`.
var derived_hgs: list<dict<any>> = []

augroup reset_derived_hg_when_colorscheme_changes | au!
    au ColorScheme * ResetDerivedHgWhenColorschemeChanges()
augroup END

def ResetDerivedHgWhenColorschemeChanges()
    for hg in derived_hgs
        Derive(hg.to, hg.from, hg.new)
    endfor
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
        var gui = has('gui_running') || &tgc
        var mode = gui ? 'gui' : 'cterm'
        var _attr: string
        var hg: string
        [_attr, hg] = items(attr)[0]
        var code = hlID(hg)
        ->synIDtrans()
        ->synIDattr(_attr, mode)
        if code =~# '^' .. (gui ? '#\x\+' : '\d\+') .. '$'
            return mode .. _attr .. '=' .. code
        endif
    endif
    return ''
enddef

