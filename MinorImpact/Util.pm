package MinorImpact::Util;

=head1 NAME


=head1 SYNOPSIS

=head1 DESCRIPTION

=head2 Methods

=cut

use Time::Local;
use Exporter 'import';
@EXPORT = ("fromMysqlDate", 
           "toMysqlDate", 
           "uniq", 
           "fleshDate",
           "trim"
          );

sub trim {
    my $string = shift || return;
    $string =~ s/^\s+//;
    $string =~ s/\s+$//;
    return $string;
}

sub fromMysqlDate {
    my @data = @_;
    my @dates = ();

    foreach my $date (@data) {
        if ($date =~ /^(\d{4})-(\d{1,2})-(\d{1,2}) (\d{1,2}:\d{1,2}:\d{1,2})$/) {
            my $year = $1;
            my $month = $2;
            my $mday = $3;
            my ($hour, $min, $sec)  = split(/:/, $4);

            push(@dates,timelocal($sec, $min, $hour, $mday, $month, $year));
        }
    }
    return wantarray?@dates:$dates[0];
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
    
        push @dates, ($year + 1900) . "-$mon-$mday $hour:$min:$sec";
    }
    return wantarray?@dates:$dates[0];
}

sub cloneHash {
    my $hash = shift || return;
    my $new_hash = shift || {};

    return unless (ref($hash) eq "HASH");
    foreach my $key (keys %$hash) {
        if (ref($hash->{$key}) eq "HASH") {
            $new_hash->{$key} = MinorImpact::cloneHash($hash->{$key});
        } else {
            $new_hash->{$key} = $hash->{$key};
        }
    }
    return $new_hash;
}

sub header {
    my $args = shift || {};

    my $title = $args->{title} || '';
    my $css = $args->{css} || '';
    my $other = $args->{other} || '';

    unless ($title) {
        $title = $0;
        $title =~s/^.+\/([^\/]+).cgi$/$1/;
        $title = ucfirst($title);
    }

    my $header = <<HEADER;
Content-type: text/html\n\n

<head>
    <title>$title</title>
    <style type='text/css'>
        body { background-color:white; font-family:sans-serif; }

        #top_menu { border-bottom:solid 1px black; font-size:large; }
 
        #list_menu  { }
        #list_name { font-size:large; font-weight:bold; }
 
        #view { padding-top: 20px; }
        #view_menu a { font-size:smaller; }
        #view_table { padding-top:20px; }
        #view_name { font-size: large; }
        #view_name:after { content:"\\000A"; white-space: pre;}
        $css
    </style>
    $other
</head>
<body>
HEADER
    return $header;
}

sub uniq {
    my %seen;
    return grep { !$seen{$_}++ } @_;
}

sub fleshDate {
    my $date = shift || return;

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
1;

