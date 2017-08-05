package MinorImpact::BinLib;

use Time::Local;
use Exporter 'import';
@EXPORT = (
            "commonRoot",
            "convert_cron_time_item_to_list", 
            "in_array", 
            "last_run_time", 
            "getMonth",
          );

=head2 BinLib::in_array($needle, @haystack)

 Search for the existence of a variable within an array.

 Parameters:
   $needle    An arbitrary value.
   @haystack  The array of values in which we want to check to see if $needle exists.

 Returns:
    TRUE or FALSE depending on whether @haystack contains $needle.

=cut

sub in_array {
    my $needle = shift;
    my @haystack = @_;

    return unless (scalar(@haystack) > 0);

    foreach my $hay (@haystack) {
        return 1 if ($needle eq $hay || $needle == $hay);
    }
    return;
}

=head2 BinLib::last_run_time($cron_entry[, $current_time])

 Parses a cron entry and determines the last time it should have run prior to $current_time.

 Parameters:
   $cron_entry      A standard cron entry.
   $current_time    An optional, arbitrary unixtime value to use as a comparison. Defaults to time().

 Returns:
   unixtime value (seconds send time epoch).

=cut

sub last_run_time {
    my $cron = shift || return;
    my $now = shift || time();

    my @tokens = split(/\s+/, $cron);
    my $c_min = shift(@tokens);
    my $c_hour = shift(@tokens);
    my $c_mday = shift(@tokens);
    my $c_month = shift(@tokens);
    my $c_wday = shift(@tokens);
    my @c_min = convert_cron_time_item_to_list($c_min, 'min');
    my @c_hour = convert_cron_time_item_to_list($c_hour, 'hour');
    my @c_mday = convert_cron_time_item_to_list($c_mday, 'mday');
    my @c_month = convert_cron_time_item_to_list($c_month, 'month');
    my @c_wday = convert_cron_time_item_to_list($c_wday, 'wday');

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

=head2 BinLib::convert_cron_time_item_to_list($item, $field_time)

 Internal function that returns a list of all the explicit values of a particular cron item type.
 For example, in a crontab, the month might be represented as */2.  When passed to this function
 as ('*/2','month'), would return "1,3,5,7,9,11".  Handles all the standard methods of specifying
 cron fields, including 'all' ('*'), 'inervals' ('*/3'), 'ranges' ('1-4'), and 'ranged-interval'
 ('1-7/4').

 Parameters:
   $item         A cron field, such as '*', '*/3', or '5-7'.
   $cron_field   Which field this applies to.

 Returns:
   An array of values.

=cut

sub convert_cron_time_item_to_list {
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
        my @sub_list = convert_cron_time_item_to_list($sub_item, $cron_field);

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
            push(@list,convert_cron_time_item_to_list($i, $cron_field));
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

sub processTags {
    return parseTags(@_);
}

sub getMonth {
    my $mon = shift || return;
    $mon =~s/^0+//;

    my %months = ('jan'=>1, 'january'=>1,
                'feb'=>2, 'february'=>2,
                'mar'=>3, 'march'=>3,
                'apr'=>4, 'april'=>4,
                'may'=>5,
                'jun'=>6, 'june'=>6,
                'jul'=>7, 'july'=>7,
                'aug'=>8, 'august'=>8,
                'sep' => 9, 'september' => 9, 
                'oct' => 10, 'october'=>10,
                'nov'=>11, 'november'=>11,
                'dec'=>12, 'december'=>12);
    return $months{$mon} if ($months{$mon});
    if ($mon =~/^[0-9]+$/) {
        return ( grep { $months{$_} eq $mon;} keys %months)[0];
    }
    return;
}   

1;
