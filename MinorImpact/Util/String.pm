package MinorImpact::Util::String;


=head1 NAME

MinorImpact::Util::String - MinorImpact string utility library

=head1 SYNOPSIS

  use MinorImpact::Util::String;

  $string = "  Foo  ";
  trim($string);

=head1 DESCRIPTION

Contains a set of string utility functions.

=head1 SUBROUTINES

=cut

use strict;

use Exporter 'import';
use MinorImpact::Util;

our @EXPORT = ( 
    #"extractFields",
    #"extractTags",
    #"indexOf",
    #"parseTags",
    #"randomText",
    "ptrunc",
    "trim",
    "trunc",
);


our $SELF;

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

=head2 ptrunc

=over

=item ptrunc($string)

=item ptrunc($string, $num)

=back

Returns a copy of $string reduced to no more than $num paragraphs.

=cut

sub ptrunc {
    my $string = shift || return;
    my $num = shift || 1;

    my $delim = "\r\n\r\n";
    my $text = (ref($string)?$$string:$string);

    my @pars = split($delim, $text);
    if (scalar(@pars) == 1) {
        $delim = "\r\n";
        @pars = split($delim, $text);
    }

    $text = join($delim, @pars[0 .. ($num - 1)]);
    $$string = $text if (ref($string));
    return $text;
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

=head2 trim

=over

=item trim($string)

=item trim(\$string)

=back

Removes white space from the beginning and end of $string.

  $string = "Foo  ";
  $trimmed_string = trim($string);
  # RESULT: $trimmed_string = "Foo";

If a reference is passed, $string will be altered directly.

  $string = " Bar ";
  trim(\$string);
  # RESULT: $string = "Bar";

=cut

sub trim {
    my $string = shift || return;
    my $text = ref($string)?$$string:$string;
    $text =~ s/^\s+//;
    $text =~ s/\s+$//;
    $$string = $text if (ref($string));
    return $text;
}

=head2 trunc

=over

=item trunc($string)

=item trunc($string, $length)

=back

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

=cut

sub trunc {
    my $string = shift || return;
    my $len = shift || 50;

    my $str = ref($string)?$$string:$string;
    return $str if (length($str) < $len);

    $str = substr($str, 0, ($len-3));
    my $strl = length($str);
    my $test = substr($str, -10);
    if ($test =~/ /) {
        $str = substr($str, 0, -(indexOf(' ', (reverse split(//, $test)))+1));
    }
    $$string = $str if (ref($string));
    return "$str...";
}

=head1 AUTHOR

Patrick Gillan <pgillan@minorimpact.com>

=cut


1;

