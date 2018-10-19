# NAME

MinorImpact::Util - MinorImpact utility library

# SYNOPSIS

    use MinorImpact::Util;

    $hash = { one => 1, two=> 2};
    $copy = cloneHash($hash);

# DESCRIPTION

Contains a set of basic utility functions.

# SUBROUTINES

## cloneHash

- cloneHash(\\%hash, \[\\%new\_hash\])

Returns a pointer to a copy of %hash.  If passed a second pointer to
%new\_hash it will store the copy there.

    $original = { one => 1, two => 2 };
    $copy = cloneHash($original);
    print $copy->{one};
    # OUTPUT: 1

## commonRoot

- commonRoot(@strings)

Looks at a list of strings and returns the common root of all
of them.  Returns "" if no common root exists.

    @strings = ("/usr/local", "/usr/bin", "/usr/local/bin");
    print commonRoot(@strings);
    # OUTPUT: /usr/

    @strings = ("test1", "test2", "tapioca");
    print commonRoot(@strings);
    # OUTPUT: t

    @strings = ("foo", "foobar", "bar");
    print commonRoot(@strings);
    # OUTPUT: 

## convertCronTimeItemToList

- convertCrontTimeItemToList($item, $field\_time)

Internal function that returns a list of all the explicit values of a particular cron item type.
For example, in a crontab, the month might be represented as \*/2.  When passed to this function
as ('\*/2','month'), would return "1,3,5,7,9,11".  Handles all the standard methods of specifying
cron fields, including 'all' ('\*'), 'inervals' ('\*/3'), 'ranges' ('1-4'), and 'ranged-interval'
('1-7/4').

### Parameters

- $item 

    A cron field, such as '\*', '\*/3', or '5-7'.

- $cron\_field
Which field this applies to.

### Returns

An array of values.

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

## f

- f()
- f($string)

This literally just prints an html header and  $string, (or "FUCK"
if no string is supplied), so I can make something happen on a CGI page.

    f();
    # OUTPUT:
    # Content-type: text/html
    # 
    # FUCK

## fleshDate

- fleshDate($string)

Takes a partial date and fills in the missing parts to return an approximate
epoch time value.

    print fleshDate("2001-09-11 08") . "\n";'
    # OUTPUT: 1000220400
    print fleshDate("2001-09-11 08:46") . "\n";'
    #OUTPUT: 1000223160
    fleshDate("2001-09-11 08:46:01") . "\n";'
    #OUTPUT: 1000223161

## fromMysqlDate

- fromMysqlDate(@date\_strings)

Takes one or more Mysql date strings and return an epoch time value.  Returns an array
if passed an array, otherwise returns a scalar.

    print fromMysqlDate("2001-09-11 08:46") . "\n";
    # OUTPUT: 1000223160

    print join(", ", fromMysqlDate("1999-12-31 23:59:59", "2000-01-01 00:00:00")) . "\n";
    # OUTPUT: 946713599, 946713600

## getMonth

- getMonth($string)

If passed a common month or abbreviation, returns the number of the month (1-12).  If passed
an integer from 1-12, returns the 3 letter abbreviation for the month.

    print getMonth('january');
    # OUTPUT: 1

    print getMonth(4);
    # OUTPUT: apr

## htmlEscape

- htmlEscape($string)
- htmlEscape($string, \\$new\_string)

Escape a bunch of HTML special characters.

    $escaped_string = htmlEscape($string);

Or:

    htmlEscape($string, \$escaped_string);

## isTrue

- isTrue()
- isTrue($string)

Compares the value  of $string to a list of expressions to try 
to determine whether or not it's positive, and returns "1" or "0".

    isTrue("true");
    # OUTPUT: 1
    isTrue("no");
    # OUTPUT: 0
    isTrue("false");
    # OUTPUT: 0
    isTrue("okay");
    # OUTPUT: 1
    isTrue();
    # OUTPUT: 0

Otherwise, isTrue adheres to the basic standard that if $string is set to anything
it's true, otherwise it's false.

### Returns

1 if $string is true, 0 if it is not.

## lastRunTime

- lastRunTime ($cron\_entry\[, $current\_time\])

    Parses a cron entry and determines the last time it should have run prior to $current_time.

    Parameters:
      $cron_entry      A standard cron entry.
      $current_time    An optional, arbitrary unixtime value to use as a comparison. Defaults to time().

    Returns:
      unixtime value (seconds send time epoch).

## toMysqlDate

- toMysqlDate()
- toMysqlDate($time)

Returns the current time, or the value of $time, in a value Mysql date formate (YYYY-MM-DD HH:MM:SS).

    # get the current date
    $date = toMysqlDate();
    # OUTPUT: 2018-10-18 15:35:06

    # get time an hour ago
    $old_date = toMysqlDate(time() - 3600);
    # OUTPUT: 2018-10-18 14:35:06

# AUTHOR

Patrick Gillan <pgillan@minorimpact.com>
