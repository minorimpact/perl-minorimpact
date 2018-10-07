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

# METHODS

## add

- add(\\%params)

## edit\_user

## settings

## viewHistory

- viewHistory()
- viewHistory( $field )
- viewHistory( $field, $value )

# AUTHOR

Patrick Gillan <pgillan@minorimpact.com>
