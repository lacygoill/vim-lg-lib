if exists('g:autoloaded_lg#math')
    finish
endif
let g:autoloaded_lg#math = 1

fu lg#math#is_prime(n) abort "{{{1
    let n = a:n
    if type(n) != type(0) || n < 0
        echo 'Not a positive number'
        return ''
    endif

    " 1, 2 and 3 are special cases.
    " 2 and 3 are prime, 1 is not prime.

    if n == 2 || n == 3
        return 1
    elseif n == 1 || n % 2 == 0 || n % 3 == 0
        return 0

    " Why do we test whether `n` is divisible by 2 or 3?{{{
    "
    " `n` is not a prime    ⇒    its prime factor decomposition
    "                            includes a prime number
    "
    " All prime numbers follow the form `6k - 1` or `6k + 1`.
    " EXCEPT 2 and 3.
    "
    " Indeed, any number can be written in one of the following form:
    "
    "    - 6k        divisible by 6    not prime
    "    - 6k + 1                      could be prime
    "    - 6k + 2    "            2    not prime
    "    - 6k + 3    "            3    not prime
    "    - 6k + 4    "            2    not prime
    "    - 6k + 5                      could be prime
    "
    " So, for a number to be prime, it has to follow the form `6k ± 1`.
    " Any other form would mean it's divisible by 2 or 3.
    "
    " So, `n` is NOT a prime    ⇒    its prime factor decomposition
    "                                includes a `6k ± 1` number
    "                                OR 2 OR 3
    "
    " Therefore, we have to test 2 and 3 manually.
    " Later we'll test all the `6k ± 1` numbers.
    "}}}
    endif

    " We'll begin testing if `n` is divisible by 5 (first `6k ± 1` number).
    let divisor = 5

    " `inc` is the increment we'll add to `divisor` at the end of each
    " iteration of the while loop.
    " The next divisor to test is 7, so, initially, the increment needs to be 2:
    "         7 = 5 + 2

    let inc = 2

    let sqrt = sqrt(n)
    while divisor <= sqrt

    " We could also write:     while i * i <= n{{{
    "
    " But then, each iteration of the loop would calculate `i*i`.
    " It's faster to just calculate the square root of `n` once and only
    " once, before the loop.
    "
    " Why do we stop testing after `sqrt`?
    " Suppose that `n` is not prime.
    " If all the factors in its prime factor decomposition are greater than
    " `√n` then their product is greater than `n` (which is of course
    " impossible).
    " Indeed, there's at least 2 factors in the decomposition of a non prime
    " number.
    " Therefore, if `n` is not prime, then its prime factor decomposition must
    " include at least one factor lower than `√n`:
    "
    "          n not prime             ⇒    n has a factor < √n
    "     ⇔    n has no factor < √n    ⇒    n is prime
    "}}}
        if n % divisor == 0
            return 0
        endif

        let divisor += inc

        " The `6k ± 1` numbers are:
        "
        "         5, 7, 11, 13, 17, 19 …
        "
        " To generate them, we begin with 5, then add 2, then add 4, then add
        " 2, then add 4…
        " In other words, we have to increment `i` by 2 or 4, at the end of
        " every iteration of the while loop.
        "
        " How to code that?
        " Here's one way; the sum of 2 consecutive increments will always be
        " 6 (2+4 or 4+2):
        "
        "         inc_current + inc_next = 6
        "
        " Therefore:
        "
        "         inc_next = 6 - inc_current

        let inc = 6 - inc
    endwhile

    return 1
endfu

fu lg#math#matrix_transposition(...) abort "{{{1
    " This function expects several lists as arguments, with all the same length.
    " We could imagine the lists piled up, forming a matrix.
    " The function should return a single list of lists, whose items are the
    " columns of this table.
    " This is similar to what is called, in math, a transposition:
    "
    "         https://en.wikipedia.org/wiki/Transpose
    "
    " That is, reading the  lines in a transposed matrix is  the same as reading
    " the columns in the original one.


    " handle special case where only 1 list was received (instead of 2)
    if a:0 == 1
        return map(range(len(a:1)), {i -> [a:1[i]]})
    endif

    " Check that all the arguments are lists and have the same length
    let length = len(a:1)
    for list in a:000
        if type(list) != type([]) || len(list) != length
            return -1
        endif
    endfor

    " Initialize a list of empty lists (whose number is length).
    " We can't use `repeat()`:
    "
    "         repeat([[]], length)
    "
    " … doesn't work as expected.
    " So we create a list of numbers with the same size (`range(length)`),
    " and then converts each number into [].
    let transposed = map(range(length), '[]')

    " Inside our table, we first iterate over lines (there're `a:0` lines),
    " then over columns (there're `length` columns).
    " With these nested for loops, we can reach all cells in the table:
    "
    "         a:000[i][j]    is the cell of coords [i,j]
    "
    " Imagine the upper-left corner is the origin of a coordinate system,
    "
    "         x axis goes down     = lines
    "         y axis goes right    = columns
    "
    " A cell must be added to a list of `transposed`. Which one?
    " A cell is in the j-th column / list of columns, so:    j
    for i in range(a:0)
        for j in range(length)
            call add(transposed[j], a:000[i][j])
        endfor
    endfor

    return transposed
endfu

fu lg#math#max(numbers) abort "{{{1
    " reimplement `max()` and `min()` because the builtins don't handle floats
    if !len(a:numbers)
        return 0
    endif
    let max = a:numbers[0]
    for n in a:numbers[1:]
        if n > max
            let max = n
        endif
    endfor
    return max
endfu

fu lg#math#min(numbers) abort "{{{1
    if !len(a:numbers)
        return 0
    endif
    let min = a:numbers[0]
    for n in a:numbers[1:]
        if n < min
            let min = n
        endif
    endfor
    return min
endfu

fu lg#math#read_number(n) abort "{{{1
    " Purpose:{{{
    "
    " Takes a number as input; outputs the english word standing for that number.
    " E.g.:
    "
    "     :echo lg#math#read_number(123)
    "     one hundred twenty three~
    "}}}
    let n = a:n
    let [thousand, million, billion] = range(3)->map({_,v -> pow(10, (v+1)*3)->float2nr()})
    if n >= billion
        return lg#math#read_number(n/billion)..' billion '..lg#math#read_number(n%billion)
    elseif n >= million
        return lg#math#read_number(n/million)..' million '..lg#math#read_number(n%million)
    elseif n >= thousand
        return lg#math#read_number(n/thousand)..' thousand '..lg#math#read_number(n%thousand)
    elseif n >= 100
        return lg#math#read_number(n/100)..' hundred '..lg#math#read_number(n%100)
    " Why `20` and not `10`?{{{
    "
    " Because numbers between 11 and 19 get special names.
    " You don't say  "ten one", "ten two", "ten three",  but "eleven", "twelve",
    " thirteen", ...
    "
    " See: https://english.stackexchange.com/q/7281/313834
        "}}}
    elseif n >= 20
        " Why `g:tens[n/10]` instead of `lg#math#read_number(n/10)`?{{{
        "
        " Because you don't say "two ten three" for 23, but "twenty three".
        " Also, notice how there is no word between the two expressions:
        "
        "     g:tens[n/10]..' '..lg#math#read_number(n%10)
        "                 ^^^^^^^
        "                 no word
        "
        " Previously, there was always a word (e.g. "hundred", "thousand", ...).
        " The difference in the code reflects this difference of word syntax.
        "}}}
        let num = lg#math#read_number(n%10)
        " Why the conditional operator?{{{
        "
        " Without, in the output for 20000, there would be a superfluous space:
        "
        "     twenty  thousand
        "           ^^
        "}}}
        return s:TENS[n/10]..(num is# '' ? '' : ' '..num)
    else
        " Why the conditional operator?{{{
        "
        " You never say "zero" at the end, for a number divisible by 10^2, 10^3, 10^6, 10^9...
        " E.g., you don't say "two hundred zero" for 200, but just "two hundred".
        "}}}
        return (n ? s:NUMS[n] : '')
    endif
endfu

const s:NUMS =<< trim END
    zero
    one
    two
    three
    four
    five
    six
    seven
    eight
    nine
    ten
    eleven
    twelve
    thirteen
    fourteen
    fifteen
    sixteen
    seventeen
    eighteen
    nineteen
END

const s:TENS =<< trim END
    zero
    ten
    twenty
    thirty
    fourty
    fifty
    sixty
    seventy
    eighty
    ninety
END

