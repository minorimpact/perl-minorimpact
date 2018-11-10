# NAME

MinorImpact::Util::String - MinorImpact string utility library

# SYNOPSIS

    use MinorImpact::Util::String;

    $string = "  Foo  ";
    trim($string);

# DESCRIPTION

Contains a set of string utility functions.

# SUBROUTINES

## extractTags

- extractTags(@strings)

Takes a list of strings and returns an array of tags found embedded in the strings.  If @strings
countains pointers, any tags that are found will be extracted, altering the original 
data.

    # parse these strings for tags.
    @strings = ("one #one", "#two", "tag:three four #six#");
    @tags = extractTags(@strings);
    print join(@tags, ", ");
    # OUTPUT: one, two, three, six

## htmlEscape

- htmlEscape($string)
- htmlEscape($string, \\$new\_string)

Escape a bunch of HTML special characters.

    $escaped_string = htmlEscape($string);

Or:

    htmlEscape($string, \$escaped_string);

## indexOf

- indexOf($string, @array)

Returns the position of $string in @array, 
or 'undef' if $string does not appear in @array.

     @array = ("one", "two", "foo", "spatula", "river");
     $index = indexOf("foo", @array);
     # RESULT: $index = 2
     $index = indexOf("one", @array);
     # RESULT: $index = 0
     $index = indexOf("napalm", @array);
     # RESULT: $index = undef
    

## ptrunc

- ptrunc($string)
- ptrunc($string, $num)

Returns a copy of $string reduced to no more than $num paragraphs.

## randomText

- randomText()
- randomText($word\_count)

Will generate a string $word\_count words long of gibberish for testing
purposes (or a random string of between 3 and 15 words, if 
$word\_count is not specified).

    print randomText(6) . "\n";
    # OUTPUT: ydvo o fygdbeb aydtl qeaih nyaq

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
    $short_string = trunc($string, 15);
    # RESULT: $short_string = "This is a...";

If the length of the  original $string is less than $length, trunc() will just
return $string.

    $string = "This is a string.";
    $short_string = trunc($string, 50);
    # RESULT: $short_string = "This is a string.";

If $length is not specified, the default is 50.

# AUTHOR

Patrick Gillan <pgillan@minorimpact.com>
