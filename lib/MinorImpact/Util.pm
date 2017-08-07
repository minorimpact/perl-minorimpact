package MinorImpact::Util;

=head1 NAME


=head1 SYNOPSIS

=head1 DESCRIPTION

=head2 Methods

=cut

use Data::Dumper;
use Time::Local;
use Exporter 'import';
@EXPORT = ( "cloneHash",
            "dumper",
            "extractTags",
            "f",
            "fleshDate",
            "fromMysqlDate", 
            "indexOf",
            "parseTags",
            "randomText",
            "toMysqlDate", 
            "trim",
            "trunc",
            "uniq", 
          );

sub dumper {
    my $dumpee = shift || return;
    my $dump = Dumper($dumpee);
    print "Content-type: text/html\n\n<pre>$dump</pre>\n";
}

sub cloneHash {
    my $hash = shift || return;
    my $new_hash = shift || {};

    return unless (ref($hash) eq "HASH");
    foreach my $key (keys %$hash) {
        if (ref($hash->{$key}) eq "HASH") {
            $new_hash->{$key} = cloneHash($hash->{$key});
        } else {
            $new_hash->{$key} = $hash->{$key};
        }
    }
    return $new_hash;
}

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
            trim(\$tag);
            next unless ($i++ && $tag =~/^(\w+)$/);
            $tags{$tag}++;
            $text =~s/^$tag$//m;
        }
        $$t = $text if (ref($t));
    }
    return sort map { lc($_); } keys %tags;
}

# This literally just prints an html header and a FUCK, 
# so I can make something happen on a CGI page.
sub f {
    my $fuck = shift || "FUCK";

    print "Content-type: text/html\n\n";
    print $fuck;
}

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
    return timelocal($sec, $min, $hour, $day, ($month-1), $year);
}

sub fromMysqlDate {
    my @data = @_;
    my @dates = ();

    foreach my $date (@data) {
        my $time;
        if ($date =~ /^(\d{4})-(\d{1,2})-(\d{1,2}) (\d{1,2}:\d{1,2}:\d{1,2})$/) {
            my $year = $1;
            my $month = ($2 - 1);
            my $mday = $3;
            my ($hour, $min, $sec)  = split(/:/, $4);

            $time = timelocal($sec, $min, $hour, $mday, $month, $year);
        } elsif ($date =~ /^(\d{4})-(\d{1,2})-(\d{1,2})$/) {
            my $year = $1;
            my $month = ($2 - 1);
            my $mday = $3;

            $time = timelocal(0, 0, 0, $mday, $month, $year);
        }
        push(@dates,$time);
    }
    if (scalar(@data) > 1) {
        return @dates;
    }
    return $dates[0];
}

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

sub _getConsonant {
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
    my $string = shift || return;
    my $text = ref($string)?$$string:$string;
    $text =~ s/^\s+//;
    $text =~ s/\s+$//;
    $$string = $text if (ref($string));
    return $text;
}

sub trunc {
    my $string = shift || return;
    my $len = shift || 50;

    return $string if (length($string) < $len);
    my $str = substr($string, 0, ($len-3));
    my $strl = length($str);
    my $test = substr($str, -10);
    if ($test =~/ /) {
        $str = substr($str, 0, -(indexOf(' ', (reverse split(//, $test)))+1));
    }
    return "$str...";
}

# returns only the unique values of an array.  But also
#   MAINTAINS THE ORDER.  I rely on this in places, so
#   don't fuck around with it.
sub uniq {
    my %seen;
    return grep { !$seen{$_}++ } @_;
}

1;

