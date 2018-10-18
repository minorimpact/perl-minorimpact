# NAME

MinorImpact::WWW

# SYNOPSIS

    use MinorImpact;

    MinorImpact::www({ actions => { index => \&index } });

    sub index {
      my $MINORIMPACT = shift || return;
      my $params = shift || {};

      # Do some custom stuff.
      MinorImpact::WWW::index($MINORIMPACT, $params);
    }

# SUBROUTINES

## add

- add(\\%params)

## edit\_user

## home

- home($MINORIMPACT, \[\\%params\])

Display all the objects found by executing $params->{query}.  If query is not defined, 
pull a list of everything the user owns.  This action/page requires a currently
logged in user.

## index

- ::($MINORIMPACT, \\%params)

The main site page, what's displayed to the world.  By default, 

## settings

## viewHistory

- viewHistory()
- viewHistory( $field )
- viewHistory( $field, $value )

# AUTHOR

Patrick Gillan <pgillan@minorimpact.com>
