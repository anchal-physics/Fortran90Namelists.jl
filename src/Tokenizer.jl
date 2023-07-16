export Tokenizer, update!, lex!, lexstring!

const PUNCTUATION = (
    '=',
    '*',
    '/',
    '\\',
    '(',
    ')',
    '[',
    ']',
    '{',
    '}',
    ',',
    ':',
    ';',
    '%',
    '&',
    '~',
    '<',
    '>',
    '?',
    '`',
    '|',
    '$',
    '#',
    '@',
)
const WHITESPACE = (' ', '\t', '\r', '\v', '\f')  # '\v' => '\x0b', '\f' => '\x0c' in Python

mutable struct Tokenizer
    index::Int64
    prior_char::Char
    char::Char
    prior_delim::Char
    group_token::Char
    Tokenizer(index=0, prior_char='\0', char='\0', prior_delim='\0', group_token='\0') =
        new(index, prior_char, char, prior_delim, group_token)
end

"""
    update_chars(tk::Tokenizer)

Update the current charters in the tokenizer.
"""
function update!(tk::Tokenizer, chars::Iterators.Stateful)
    tk.prior_char, tk.char = tk.char, next(chars, '\n')
    tk.index += 1
    return tk
end

function lex!(tk::Tokenizer, line)
    tokens = String[]
    tk.index = 0   # Bogus value to ensure `index` = 1 after the first iteration
    chars = Iterators.Stateful(line)  # An iterator generated by `line`
    update!(tk, chars)
    while tk.char != '\n'
        # Update namelist group status
        if tk.char in ('&', '$')
            tk.group_token = tk.char
        end
        if tk.group_token == '&' && tk.char == '/' ||
            tk.group_token == '$' && tk.char == '$'
            # A namelist ends, the value cannot be the default value (`nothing`)
            # Because it is being compared below
            tk.group_token = '\0'
        end
        word = ""  # Create or clear `word`
        if tk.char in WHITESPACE  # Ignore whitespace
            while tk.char in WHITESPACE
                word *= tk.char  # Read one char to `word`
                update!(tk, chars)  # Read the next char until meet a non-whitespace char
            end
        elseif tk.char == '!' || tk.group_token === '\0'  # Ignore comment
            # Abort the iteration and build the comment token
            word = line[(tk.index):end]  # There is no '\n' at line end, no worry! Lines are already separated at line ends
            tk.char = '\n'
        elseif tk.char in ('\'', '"') || tk.prior_delim !== '\0'  # Lex a string
            word = lexstring!(tk, chars)
        elseif tk.char in PUNCTUATION
            word = tk.char
            update!(tk, chars)
        else
            while !(isspace(tk.char) || tk.char in PUNCTUATION)
                word *= tk.char
                update!(tk, chars)
            end
        end
        push!(tokens, string(word))
    end
    return tokens
end

"""
    lexstring(tk::Tokenizer)

Tokenize a Fortran string.
"""
function lexstring!(tk::Tokenizer, chars::Iterators.Stateful)
    word = ""
    if tk.prior_delim !== '\0'  # A previous quotation mark presents
        delim = tk.prior_delim  # Read until `delim`
        tk.prior_delim = '\0'
    else
        delim = tk.char  # No previous quotation mark presents
        word *= tk.char  # Read this character
        update!(tk, chars)
    end
    while true
        if tk.char == delim
            # Check for escaped delimiters
            update!(tk, chars)
            if tk.char == delim
                word *= delim^2
                update!(tk, chars)
            else
                word *= delim
                break
            end
        elseif tk.char == '\n'
            tk.prior_delim = delim
            break
        else
            word *= tk.char
            update!(tk, chars)
        end
    end
    return word
end

function next(chars::Iterators.Stateful, default)
    x = iterate(chars)
    return x === nothing ? default : first(x)
end
