if exists('g:autoloaded_lg#math')
    finish
endif
let g:autoloaded_lg#math = 1

fu lg#math#max(numbers) abort "{{{1
    " reimplement `max()` and `min()` because the builtins don't handle floats
    if !len(a:numbers) | return 0 | endif
    let max = a:numbers[0]
    for n in a:numbers[1:]
        if n > max
            let max = n
        endif
    endfor
    return max
endfu

fu lg#math#min(numbers) abort "{{{1
    if !len(a:numbers) | return 0 | endif
    let min = a:numbers[0]
    for n in a:numbers[1:]
        if n < min
            let min = n
        endif
    endfor
    return min
endfu

