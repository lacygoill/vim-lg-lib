vim9script

export def Max(numbers: any): any #{{{1
    # TODO:
    # `numbers: any` → `numbers: list<number|float>`
    # `): any`       → `): float`

    # reimplement `max()` and `min()` because the builtins don't handle floats

    if empty(numbers) | return 0 | endif
    # TODO: Once Vim9 supports list slicing, refactor the next lines:{{{
    #
    #     let max = remove(numbers, 0)
    #     for n in numbers
    #
    #     →
    #
    #     let max = numbers[0]
    #     for n in numbers[1:]
    #}}}
    let max = remove(numbers, 0)
    for n in numbers
        if n > max
            max = n
        endif
    endfor
    return max
enddef

export def Min(numbers: float): float #{{{1
    if empty(numbers) | return 0.0 | endif
    let min = remove(numbers, 0)
    for n in numbers
        if n < min
            min = n
        endif
    endfor
    return min
enddef

export def MatrixTransposition(lists: list<list<any>>): any #{{{1
    # TODO: Once Vim9 supports `{type}|{type}` change the return type of the function to `list<list<any>>|number`
    # This function expects a list of lists; each list with with the same size.{{{
    #
    # You could imagine the lists piled up, forming a matrix.
    #
    # The function  should return  another list  of lists,  whose items  are the
    # columns of  this table.   This is similar  to what is  called, in  math, a
    # transposition: https://en.wikipedia.org/wiki/Transpose
    # That is, reading the  lines in a transposed matrix is  the same as reading
    # the columns in the original one.
    #}}}
    # Usage example:{{{
    #
    #     :echo Matrix_transposition([[1, 2], [3, 4], [5, 6]])
    #     [[1, 3, 5], [2, 4, 6]]~
    #}}}

    let n_lines = len(lists)
    if type(lists) != v:t_list || n_lines == 0
        return -1
    endif

    let firstlist = lists[0]
    # handle special case where only 1 list was received (instead of 2)
    if n_lines == 1
        return len(firstlist)->range()->map({i -> [firstlist[i]]})
    endif

    # Check that all the arguments are lists and have the same length
    let n_columns = len(firstlist)
    for list in lists
        if type(list) != type([]) || len(list) != n_columns
            return -1
        endif
    endfor

    # Initialize a list of empty lists (whose number is `n_columns`).{{{
    #
    # We can't use `repeat()`:
    #
    #     repeat([[]], n_columns)
    #
    # ... doesn't work as expected.
    #
    # So we  create a list of  numbers with the same  size (`range(n_columns)`),
    # and then converts each number into `[]`.
    #}}}
    let transposed = range(n_columns)->map('[]')

    # Inside our table, we first iterate over lines, then over columns.{{{
    #
    # With these nested for loops, we can reach all cells in the table:
    #
    #     lists[i][j]    is the cell of coords [i,j]
    #
    # Imagine the upper-left corner is the origin of a coordinate system,
    #
    #     x axis goes down = lines
    #     y axis goes right = columns
    #
    # A cell must be added to a list of `transposed`.  Which one?
    # A cell is in the `j`-th column / list of columns, so: `j`.
    #}}}
    for i in range(n_lines)
        for j in range(n_columns)
            call add(transposed[j], lists[i][j])
        endfor
    endfor

    return transposed
enddef

