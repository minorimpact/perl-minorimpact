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
            "fleshDate",
            "fromMysqlDate", 
            "indexOf",
            "parseTags",
            "toMysqlDate", 
            "uniq", 
            "trim"
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
            $tags{$tag}++ if ($tag);
        }
    }
    return sort keys %tags;
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
    $string =~ s/^\s+//;
    $string =~ s/\s+$//;
    return $string;
}

sub uniq {
    my %seen;
    return grep { !$seen{$_}++ } @_;
}

1;

