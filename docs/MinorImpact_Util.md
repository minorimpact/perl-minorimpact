# NAME

# SYNOPSIS

# DESCRIPTION

## Methods

- convertCronTimeItemToList($item, $field\_time)

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

- lastRunTime($cron\_entry\[, $current\_time\])

        Parses a cron entry and determines the last time it should have run prior to $current_time.

        Parameters:
          $cron_entry      A standard cron entry.
          $current_time    An optional, arbitrary unixtime value to use as a comparison. Defaults to time().

        Returns:
          unixtime value (seconds send time epoch).

# POD ERRORS

Hey! **The above document had some coding errors, which are explained below:**

- Around line 82:

    '=item' outside of any '=over'

    &#x3d;over without closing =back
