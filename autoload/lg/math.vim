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

fu lg#math#matrix_transposition(lists) abort "{{{1
    " This function expects a list of lists; each list with with the same size.{{{
    "
    " You could imagine the lists piled up, forming a matrix.
    "
    " The function  should return  another list  of lists,  whose items  are the
    " columns of  this table.   This is similar  to what is  called, in  math, a
    " transposition: https://en.wikipedia.org/wiki/Transpose
    " That is, reading the  lines in a transposed matrix is  the same as reading
    " the columns in the original one.
    "}}}
    " Usage example:{{{
    "
    "     :echo lg#math#matrix_transposition([[1,2], [3,4], [5,6]])
    "     [[1, 3, 5], [2, 4, 6]]~
    "}}}

    let n_lines = len(a:lists)
    if type(a:lists) != v:t_list || n_lines == 0
        return -1
    endif

    let firstlist = a:lists[0]
    " handle special case where only 1 list was received (instead of 2)
    if n_lines == 1
        return map(range(len(firstlist)), {i -> [firstlist[i]]})
    endif

    " Check that all the arguments are lists and have the same length
    let n_columns = len(firstlist)
    for list in a:lists
        if type(list) != type([]) || len(list) != n_columns
            return -1
        endif
    endfor

    " Initialize a list of empty lists (whose number is `n_columns`).{{{
    "
    " We can't use `repeat()`:
    "
    "     repeat([[]], n_columns)
    "
    " ... doesn't work as expected.
    "
    " So we  create a list of  numbers with the same  size (`range(n_columns)`),
    " and then converts each number into `[]`.
    "}}}
    let transposed = map(range(n_columns), '[]')

    " Inside our table, we first iterate over lines, then over columns.{{{
    "
    " With these nested for loops, we can reach all cells in the table:
    "
    "     a:lists[i][j]    is the cell of coords [i,j]
    "
    " Imagine the upper-left corner is the origin of a coordinate system,
    "
    "     x axis goes down     = lines
    "     y axis goes right    = columns
    "
    " A cell must be added to a list of `transposed`. Which one?
    " A cell is in the j-th column / list of columns, so:    j
    "}}}
    for i in range(n_lines)
        for j in range(n_columns)
            call add(transposed[j], a:lists[i][j])
        endfor
    endfor

    return transposed
endfu

