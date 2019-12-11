if exists('g:loaded_lg#lib#reg')
    finish
endif
let g:loaded_lg#lib#reg = 1

let s:REG_TRANSLATIONS = {
\                          '"': 'unnamed',
\                          '+': 'plus',
\                          '-': 'minus',
\                          '*': 'star',
\                          '/': 'slash',
\                        }

fu lg#reg#restore(names) abort "{{{1
    for name in a:names
        let prefix   = get(s:REG_TRANSLATIONS, name, name)
        let contents = s:{prefix}_save[0]
        let type     = s:{prefix}_save[1]

        " FIXME: how to restore `0` {{{

        " When we restore use `setreg()` or `:let`, we can't make
        " a distinction between the unnamed and copy registers.
        " IOW, whatever we do to one of them, we do it to the other.
        "
        " Why are they synchronized with `setreg()` and `:let`?
        " They aren't in normal mode. If I copy some text, they will be
        " identical. But if I delete some other text just afterwards, they
        " will be different.
        "
        " I could understand the synchronization in one direction:
        "
        "     change @0    →    change @"
        "
        " … because one could argue that the unnamed register points to the
        " last changed register. So, when we change the contents of the copy
        " register, the unnamed points to the latter. OK, why not.
        " But I can't understand in the other direction:
        "
        "     change @"    →    change @0
        "
        " If I execute:
        "
        "     :call setreg('"', 'unnamed')
        "
        " … why does the copy register receives the same contents?
        "
        " This cause a problem for all functions (operators) which need to
        " temporarily copy some text, want to restore the unnamed register
        " as well as the copy register to whatever old values they had, and
        " those 2 registers are different at the time the function was
        " invoked.
        "
        " That's why, at the moment, I don't try to restore the copy register
        " in ANY operator function. I simply CAN'T.
        "}}}

        call setreg(name, contents, type)
    endfor
endfu

fu lg#reg#save(names) abort "{{{1
    for name in a:names
        let prefix          = get(s:REG_TRANSLATIONS, name, name)
        let s:{prefix}_save = [getreg(name), getregtype(name)]
    endfor
endfu
