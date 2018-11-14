package MinorImpact::Util::String;

=head1 NAME

MinorImpact::Util::String - MinorImpact string utility library

=head1 SYNOPSIS

  use MinorImpact::Util::String;

  $string = "  Foo  ";
  trim($string);       # "Foo"

=head1 DESCRIPTION

Contains a set of string utility functions.

=head1 SUBROUTINES

=cut

use strict;

use Exporter 'import';
use MinorImpact::Util;

our @EXPORT = ( 
    "ptrunc",
    "trim",
    "trunc",
);


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
  $short_string = trunc($string, 15);  # "This is a..."

If the length of the  original $string is less than $length, trunc() will just
return $string.

  $string = "This is a string.";
  $short_string = trunc($string, 50);  # "This is a string."

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
        $str = substr($str, 0, -(MinorImpact::Util::indexOf(' ', (reverse split(//, $test)))+1));
    }
    $$string = $str if (ref($string));
    return "$str...";
}

=head1 AUTHOR

Patrick Gillan <pgillan@minorimpact.com>

=cut


1;

