package MinorImpact::Util;


=head1 NAME

MinorImpact::Util - MinorImpact utility library

=head1 SYNOPSIS

  use MinorImpact::Util;

  $hash = { one => 1, two=> 2};
  $copy = cloneHash($hash);

=head1 DESCRIPTION

Contains a set of basic utility functions.

=head1 SUBROUTINES

=cut

use strict;

use Data::Dumper;
use MinorImpact::Util::String;
use Time::Local;
use Data::UUID;

use Exporter 'import';
our @EXPORT = ( 
    "clone",
    "cloneHash",
    "commonRoot",
    "convertCronTimeItemToList",
    "dumper",
    "extractFields",
    "extractTags",
    "f",
    "fleshDate",
    "fromMysqlDate", 
    "getMonth",
    "htmlEscape",
    "indexOf",
    "isTrue",
    "lastRunTime",
    "parseTags",
    "randomText",
    "toMysqlDate", 
    "trim",
    "trunc",
    "uniq", 
    "uuid",
);


our $SELF;

sub clone {
    my $original = shift;
    my $copy;

    if (ref($original) eq "HASH") {
        $copy = cloneHash($original);
    } elsif (ref($original) eq "ARRAY") {
        $copy = cloneArray($original);
    } else {
        $copy = $original;
    }

    return $copy;
}

=head2 cloneArray

Returns a deep copy of an array pointer.

=cut

sub cloneArray {
    my $array = shift || return;
    my $new_array = shift || [];

    die "not an array reference" unless (ref($array) eq "ARRAY");
    foreach my $value (@$array) {
        push(@$new_array, clone($value));
    }
    return $new_array;
}

=head2 cloneHash

=over

=item cloneHash(\%hash, [\%new_hash])

=back

Returns a pointer to a copy of %hash.  If passed a second pointer to
%new_hash it will store the copy there.

  $original = { one => 1, two => 2 };
  $copy = cloneHash($original);
  print $copy->{one};
  # OUTPUT: 1

=cut

sub cloneHash {
    my $hash = shift || return;
    my $new_hash = shift || {};

    die "not a hash reference\n"  unless (ref($hash) eq "HASH");
    foreach my $key (keys %$hash) {
        #if (ref($hash->{$key}) eq "HASH") {
        #    $new_hash->{$key} = cloneHash($hash->{$key});
        #} elsif (ref($hash->{$key}) eq "ARRAY") {
        #    $new_hash->{$key} = cloneArray($hash->{$key});
        #} else {
        #    $new_hash->{$key} = $hash->{$key};
        #}
        $new_hash->{$key} = clone($hash->{$key});
    }
    return $new_hash;
}

=head2 commonRoot

=over

=item commonRoot(@strings)

=back

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

=cut

sub commonRoot {
    my $root;
    foreach my $file (@_) {
        unless ($root) {
            $root = $file;
            next;
        }
        my $pos = 0;
        my $newroot;
        my @chars = split(//, $file);
        my @root = split(//, $root);
        foreach my $char (@chars) {
            if ($char eq $root[$pos]) {
                $newroot .= $char;
            } else {
                $root = $newroot;
                last;
            }
            $pos++;
        }
    }

    return $root;
}

=head2 convertCronTimeItemToList

=over

=item convertCrontTimeItemToList($item, $field_time)

=back

Internal function that returns a list of all the explicit values of a particular cron item type.
For example, in a crontab, the month might be represented as */2.  When passed to this function
as ('*/2','month'), would return "1,3,5,7,9,11".  Handles all the standard methods of specifying
cron fields, including 'all' ('*'), 'inervals' ('*/3'), 'ranges' ('1-4'), and 'ranged-interval'
('1-7/4').

=head3 Parameters

=over

=item $item 

A cron field, such as '*', '*/3', or '5-7'.

=item $cron_field
Which field this applies to.

=back

=head3 Returns

An array of values.

=cut

sub convertCronTimeItemToList {
    my $item = shift;
    my $cron_field = shift || return;

    return if ($item eq '');

    if ($cron_field eq 'wday') {
        $item =~s/Sun/0/;
        $item =~s/Mon/1/;
        $item =~s/Tue/2/;
        $item =~s/Wed/3/;
        $item =~s/Thu/4/;
        $item =~s/Fri/5/;
        $item =~s/Sat/6/;
    }

    $item =~s/^0(\d)/$1/;
    $item =~s/^ (\d)/$1/;

    my $max;

    $max = 59 if ($cron_field eq 'min');
    $max = 23 if ($cron_field eq 'hour');
    $max = 30 if ($cron_field eq 'mday');
    $max = 11 if ($cron_field eq 'month');
    $max = 6 if ($cron_field eq 'wday');
    return unless ($max);

    my @list = ();
    if ($item =~/^(.*)\/(\d+)$/) {
        my $sub_item = $1;
        my $step = $2;
        # some crons have minute = "*/60". This gets translated as "0" by crond.
        if ($step > $max) {
            return (0);
        }
        my @sub_list = convertCronTimeItemToList($sub_item, $cron_field);

        my $count = $step;
        foreach my $i (@sub_list) {
            if ($count == $step) {
                push(@list, $i);
                $count = 0;
            }
            $count++;
        }
    } elsif ($item eq '*') {
        @list = (0..$max);
        if ($cron_field eq 'mday') {
            @list = map {$_+1 } @list;
        }
    } elsif ($item =~/,/) {
        foreach my $i (split(',', $item)) {
            push(@list,convertCronTimeItemToList($i, $cron_field));
        }
    } elsif ($item =~/^(\d+)-(\d+)$/) {
        my $first = $1;
        my $last = $2;
        if ($cron_field eq 'month') {
            $first--;
            $last--;
        }
        @list = ($first..$last);
    } elsif ($item =~/^\d+$/) {
        if ($cron_field eq 'month') {
            $item--;
        }
        if ($cron_field eq 'wday' && $item == 7) {
            $item = 0;
        }
        @list = ($item);
    }

    return @list;
}

sub dumper {
    my $dumpee = shift || return;
    my $dump = Dumper($dumpee);
    print "Content-type: text/html\n\n<pre>$dump</pre>\n";
}

sub extractFields {
    my %fields;
    foreach my $t (@_) {
        my $text = ref($t)?$$t:$t;
        $text =~s/\r\n/\n/g;
        while ($text =~/(\w+[:=]\S+)/g) {
            my $match = $&;
            my ($key, $value) = $match =~/(\w+)[:=](\S+)/;
            MinorImpact::log('debug', "$key='$value'");
            $fields{$key} = $value;
            $text =~s/$match//;
        }
        $$t = $text if (ref($t));
    }
    return \%fields;
}

=head2 extractTags

=over

=item extractTags(@strings)

=back

Takes a list of strings and returns an array of tags found embedded in the strings.  If @strings
countains pointers, any tags that are found will be extracted, altering the original 
data.

  # parse these strings for tags.
  @strings = ("one #one", "#two", "tag:three four #six#");
  @tags = extractTags(@strings);
  print join(@tags, ", ");
  # OUTPUT: one, two, three, six

=cut

sub extractTags {
    my %tags;
    foreach my $t (@_) {
        my $text = ref($t)?$$t:$t;
        $text =~s/\r\n/\n/g;
        foreach my $tag ($text =~/tag:(\w+)/g) {
            $tags{$tag}++;
            $text =~s/tag:$tag//;
        }
        foreach my $tag ($text =~/(?<!#)#(\w+)/g) {
            $tags{$tag}++;
            $text =~s/#$tag//;
        }
        $text =~s/##/#/g;
        my $i = 0;
        foreach my $tag (split("\n", $text)) {
            # ignore the first line.
            next unless ($i++ && $tag =~/^\s*(\w+)\s*$/);
            $tags{$tag}++;
            $text =~s/^\s*$tag\s*$//m;
        }
        $$t = $text if (ref($t));
    }
    return sort uniq map { lc($_); } keys %tags;
}

=head2 f

=over

=item f()

=item f($string)

=back

This literally just prints an html header and  $string, (or "FUCK"
if no string is supplied), so I can make something happen on a CGI page.

  f();
  # OUTPUT:
  # Content-type: text/html
  # 
  # FUCK

=cut

sub f {
    my $fuck = shift || "FUCK";

    print "Content-type: text/html\n\n";
    print $fuck;
}

=head2 fleshDate

=over

=item fleshDate($string)

=back

Takes a partial date and fills in the missing parts to return an approximate
epoch time value.

  print fleshDate("2001-09-11 08") . "\n";'
  # OUTPUT: 1000220400
  print fleshDate("2001-09-11 08:46") . "\n";'
  #OUTPUT: 1000223160
  fleshDate("2001-09-11 08:46:01") . "\n";'
  #OUTPUT: 1000223161

=cut

sub fleshDate {
    my $date = trim(shift) || return;

    my ($year, $month, $day, $hour, $min, $sec) = (0, 1, 1, 0, 0, 0);
    if ($date =~/^(\d{4})-(\d{1,2})-(\d{1,2}) (\d{1,2}):(\d{1,2}):(\d{1,2})$/) {
        $year = $1;
        $month = $2;
        $day = $3;
        $hour = $4;
        $min = $5;
        $sec = $6;
    } elsif ($date =~/^(\d{4})-(\d{1,2})-(\d{1,2}) (\d{1,2}):(\d{1,2})$/) {
        $year = $1;
        $month = $2;
        $day = $3;
        $hour = $4;
        $min = $5;
    } elsif ($date =~/^(\d{4})-(\d{1,2})-(\d{1,2}) (\d{1,2})$/) {
        $year = $1;
        $month = $2;
        $day = $3;
        $hour = $4;
    } elsif ($date =~/^(\d{4})-(\d{1,2})-(\d{1,2})$/) {
        $year = $1;
        $month = $2;
        $day = $3;
    } elsif ($date =~/^(\d{4})-(\d{1,2})$/) {
        $year = $1;
        $month = $2;
    } elsif ($date =~/^(\d{4})$/) {
        $year = $1;
    } else {
        return;
    }
    $month = $month - 1 if ($month > 0);
    $day = 1 if ($day eq '0' || $day eq '00');
    return timelocal($sec, $min, $hour, $day, $month, $year);
}

=head2 fromMysqlDate

=over

=item fromMysqlDate(@date_strings)

=back

Takes one or more Mysql date strings and return an epoch time value.  Returns an array
if passed an array, otherwise returns a scalar.

  print fromMysqlDate("2001-09-11 08:46") . "\n";
  # OUTPUT: 1000223160

  print join(", ", fromMysqlDate("1999-12-31 23:59:59", "2000-01-01 00:00:00")) . "\n";
  # OUTPUT: 946713599, 946713600

=cut

sub fromMysqlDate {
    my @data = @_;
    my @dates = ();

    foreach my $date (@data) {
        push(@dates, fleshDate($date));
    }
    if (scalar(@data) > 1) {
        return @dates;
    }
    return $dates[0];
}

=head2 getMonth

=over

=item getMonth($string)

=back

If passed a common month or abbreviation, returns the number of the month (1-12).  If passed
an integer from 1-12, returns the 3 letter abbreviation for the month.

  print getMonth('january');
  # OUTPUT: 1

  print getMonth(4);
  # OUTPUT: apr

=cut

sub getMonth {
    my $mon = lc(shift) || return;
    $mon =~s/^0+//;

    my %months = ('jan'=>1, 'january'=>1,
                'feb'=>2, 'february'=>2,
                'mar'=>3, 'march'=>3,
                'apr'=>4, 'april'=>4,
                'may'=>5,
                'jun'=>6, 'june'=>6,
                'jul'=>7, 'july'=>7,
                'aug'=>8, 'august'=>8, augst => 8,
                'sep' => 9, 'september' => 9, 'sept' => 9,
                'oct' => 10, 'october'=>10,
                'nov'=>11, 'november'=>11,
                'dec'=>12, 'december'=>12);
    return $months{$mon} if ($months{$mon});

    if ($mon =~/^[0-9]+$/) {
        return ( grep { $months{$_} eq $mon;} keys %months)[0];
    }
    return;
}

=head2 htmlEscape

=over

=item htmlEscape($string)

=item htmlEscape($string, \$new_string)

=back

Escape a bunch of HTML special characters.

  $escaped_string = htmlEscape($string);

Or:

  htmlEscape($string, \$escaped_string);

=cut

sub htmlEscape {
    my $string = shift || return;
    my $text = ref($string)?$$string:$string;
    $text =~ s/&/&amp;/g;
    $text =~ s/</&lt;/g;
    $text =~ s/>/&gt;/g;
    $text =~ s/"/&quot;/g;
    $text =~ s/'/&#39;/g;
    $$string = $text if (ref($string));
    return $text;
}

=head2 indexOf

=over

=item indexOf($string, @array)

=back

Returns the position of $string in @array, 
or 'undef' if $string does not appear in @array.

  @array = ("one", "two", "foo", "spatula", "river");
  $index = indexOf("foo", @array);
  # RESULT: $index = 2
  $index = indexOf("one", @array);
  # RESULT: $index = 0
  $index = indexOf("napalm", @array);
  # RESULT: $index = undef
 
=cut

sub indexOf {
    my $string = shift || return;
    my @data = @_;

    for (my $i=0; $i< scalar(@data); $i++) {
        return $i if ($data[$i] eq $string);
    }
    return undef;
}

=head2 isTrue

=over

=item isTrue()

=item isTrue($string)

=back

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

=head3 Returns

1 if $string is true, 0 if it is not.

=cut

sub isTrue {
    my $string = lc(shift) || return 0;

    my $TRUISMS = {
        "1" => 1,
        "0" => 0,
        "absolutely" => 1,
        "absolutely not" => 0,
        "affirmative" => 1,
        "almost" => 0,
        "bonza" => 1,
        "certainly" => 1,
        "damn straight" => 1,
        "false" => 0,
        "fuck no" => 0,
        "fuck yes" => 1,
        "negative" => 0,
        "nein" => 0,
        "never" => 0,
        "no" => 0,
        "not cool" => 0,
        "not true" => 0,
        "off" => 0,
        "ok" => 1,
        "okay" => 1,
        "nyet" => 0,
        "right" => 1,
        "shit yeah" => 1,
        "sure" => 1,
        "true" => 1,
        "why not" => 1,
        "wrong" => 0,
        "yes" => 1,
    };

    if (defined($TRUISMS->{$string})){
        return $TRUISMS->{$string};
    } elsif ($string) {
        return 1;
    } else {
        return 0;
    }
}

=head2 lastRunTime

=over

=item lastRunTime ($cron_entry[, $current_time])

=back

 Parses a cron entry and determines the last time it should have run prior to $current_time.

 Parameters:
   $cron_entry      A standard cron entry.
   $current_time    An optional, arbitrary unixtime value to use as a comparison. Defaults to time().

 Returns:
   unixtime value (seconds send time epoch).

=cut

sub lastRunTime {
    my $cron = shift || return;
    my $now = shift || time();

    my @tokens = split(/\s+/, $cron);
    my $c_min = shift(@tokens);
    my $c_hour = shift(@tokens);
    my $c_mday = shift(@tokens);
    my $c_month = shift(@tokens);
    my $c_wday = shift(@tokens);
    my @c_min = convertCronTimeItemToList($c_min, 'min');
    my @c_hour = convertCronTimeItemToList($c_hour, 'hour');
    my @c_mday = convertCronTimeItemToList($c_mday, 'mday');
    my @c_month = convertCronTimeItemToList($c_month, 'month');
    my @c_wday = convertCronTimeItemToList($c_wday, 'wday');

    my $test_time = $now;
    my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = localtime($test_time);

    until ( 
            (in_array($min, @c_min) && in_array($hour, @c_hour) && in_array($mon, @c_month)) &&
            (   
                (   
                    (scalar(@c_mday) < 31 && in_array($mday, @c_mday)) ||
                    (scalar(@c_wday) < 7 && in_array($wday, @c_wday))
                ) || ( scalar(@c_mday) == 31 && scalar(@c_wday) == 7)
            )
        ) {
        $test_time = $test_time - 60;
        ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = localtime($test_time);

        # Prevent (nearly) infinite loops by exiting out if we have to go back more than a year.
        return -1 if ($test_time < ($now - 31536000));
    }

    my $then = timelocal(0,$min, $hour, $mday, $mon, $year);
    return $then;
}

sub parseTags {
    my %tags;
    foreach my $tags (@_) {
        foreach my $tag (split(/\W+/, $tags)) {
            $tag = lc($tag);
            $tag =~s/\W//g;
            $tag =~s/^#+//;
            $tags{$tag}++ if ($tag);
        }
    }
    return sort map { lc($_); } keys %tags;
}

sub _consonant {
    my $letter = _getLetter();
    while (_isNoun($letter)) {
        $letter = _getLetter();
    }
    return $letter;
}

sub _getLetter {
    my $letter = chr(int(rand(26))+97);
    if (indexOf($letter, ('q','x','z')) && rand(100) > .5) {
        $letter = _getLetter();
    } elsif (indexOf($letter, ('y')) && rand(100) > 1) {
        $letter = _getLetter();
    }

    return $letter;
}

sub _getNoun {
    my $letter = _getLetter();
    while (!_isNoun($letter)) {
        $letter = _getLetter();
    }
    return $letter;
}

sub _isNoun {
    my $letter = shift || return;;
    my @nouns = ('a', 'e', 'i', 'o', 'u');
    push (@nouns, 'y') if (int(rand(100)) > 5);
    return indexOf($letter, @nouns);
}

=head2 randomText

=over

=item randomText()

=item randomText($word_count)

=back

Will generate a string $word_count words long of gibberish for testing
purposes (or a random string of between 3 and 15 words, if 
$word_count is not specified).

  print randomText(6) . "\n";
  # OUTPUT: ydvo o fygdbeb aydtl qeaih nyaq

=cut

sub randomText {
    my $word_count = shift;
    $word_count =~s/\D//g;
    $word_count ||= int(rand(13)) + 3;

    my $text;
    for (my $i = 0; $i < $word_count; $i++) {
        my $word;
        my $letter_count = int(rand(5)) + int(rand(5)) + 1;
        my $last_letter;
        for (my $j = 1; $j <= $letter_count; $j++) {
            my $letter = _getLetter();
            redo if ($letter_count == 1 && !_isNoun($letter) && rand(100) > .001);
            redo if ($last_letter && $last_letter eq $letter && rand(100) > 2);
            redo if (_isNoun($letter) && !$last_letter && rand(100) > 40);
            redo if (!_isNoun($letter) && $last_letter && !_isNoun($last_letter) && rand(100) > 10);
            redo if (_isNoun($letter) && $last_letter && _isNoun($last_letter) && rand(100) > 15);
            
            $letter = 'y' if ($j == $letter_count && $letter !~/y/ && rand(100) < 3);
            $word .= $letter;
            $last_letter = $letter;
        }
        my $nouns = 0;
        foreach my $letter (split(//, $word)) {
            $nouns++ if (_isNoun($letter));
        }
        redo if ($nouns == 0 && rand(100) > .001);
        redo if ($nouns == length($word) && length($word) > 1 && rand(100) > .001);
        $text .= "$word ";
    }
    trim(\$text);
    return $text;
}

=head2 toMysqlDate

=over

=item toMysqlDate()

=item toMysqlDate($time)

=back

Returns the current time, or the value of $time, in a value Mysql date formate (YYYY-MM-DD HH:MM:SS).

  # get the current date
  $date = toMysqlDate();
  # OUTPUT: 2018-10-18 15:35:06

  # get time an hour ago
  $old_date = toMysqlDate(time() - 3600);
  # OUTPUT: 2018-10-18 14:35:06

=cut

sub toMysqlDate {
    my @data = @_;
    my @dates = ();
    if (scalar(@data) == 0) {
        push(@data, time());
    }

    foreach my $time (@data) {
        my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($time);
        $mon++;
        $mon = "0$mon" if ($mon < 10);
        $mday = "0$mday" if ($mday < 10);
        $hour = "0$hour" if ($hour < 10);
        $min = "0$min" if ($min < 10);
        $sec = "0$sec" if ($sec < 10);
    
        my $date =  ($year + 1900) . "-$mon-$mday $hour:$min:$sec";
        $date =~s/ 00:00:00$//;
        push(@dates, $date);
    }
    if (scalar(@data) > 1) {
        return @dates;
    }
    return $dates[0];
}

sub trim {
    return MinorImpact::Util::String::trim(@_);
}

=head2 trunc

Deprecated.

See L<MinorImpact::Util::String::trunc()|MinorImpact::Util::String/trunc>.

=cut

sub trunc {
    return MinorImpact::Util::String::trunc(@_);
}

=head2 uniq

=over

=item uniq(@array)

=back

Returns only the unique values of an array, while also
retaining the order.

  @foo = (1, 2, 1, 5, 4, 5, 1);
  @bar = uniq(@foo);
  # OUTPUT: @bar = (1, 2, 5, 4);

=cut

sub uniq {
    my %seen;
    # This also MAINTAINS THE ORDER.  I rely on this in places, so
    #   don't fuck around with it.
    return grep { !$seen{$_}++ } @_;
}

=head2 uuid

=over

=item uuid()

=back

Return a UUID string.

  print uuid() . "\n";

=cut

sub uuid {
    $SELF->{UG} = new Data::UUID unless (defined($SELF->{UG}) && $SELF->{UG});

    return lc($SELF->{UG}->create_str());
}

=head1 AUTHOR

Patrick Gillan <pgillan@minorimpact.com>

=cut


1;

