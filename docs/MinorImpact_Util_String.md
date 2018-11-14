# NAME

MinorImpact::Util::String - MinorImpact string utility library

# SYNOPSIS

    use MinorImpact::Util::String;

    $string = "  Foo  ";
    trim($string);       # "Foo"

# DESCRIPTION

Contains a set of string utility functions.

# SUBROUTINES

## ptrunc

- ptrunc($string)
- ptrunc($string, $num)

Returns a copy of $string reduced to no more than $num paragraphs.

## trim

- trim($string)
- trim(\\$string)

Removes white space from the beginning and end of $string.

    $string = "Foo  ";
    $trimmed_string = trim($string);
    # RESULT: $trimmed_string = "Foo";

If a reference is passed, $string will be altered directly.

    $string = " Bar ";
    trim(\$string);
    # RESULT: $string = "Bar";

## trunc

- trunc($string)
- trunc($string, $length)

Returns a copy of $string reduced to no more than $length size.  The resulting
string, if altered, will come with an ellipsis ("...") appended to indicate that 
the string continues past what's shown (which will count as part of the length to 
remain under the $length cap).  Some effort will be made to cut the original string
at a space, which makes the exact length of the returned value unknown.

    $string = "This is a string that's longer than I want it to be."
    $short_string = trunc($string, 15);  # "This is a..."

If the length of the  original $string is less than $length, trunc() will just
return $string.

    $string = "This is a string.";
    $short_string = trunc($string, 50);  # "This is a string."

If $length is not specified, the default is 50.

# AUTHOR

Patrick Gillan <pgillan@minorimpact.com>
