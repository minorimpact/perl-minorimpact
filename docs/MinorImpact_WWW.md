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

## edit

- edit($MINORIMPACT, \[\\%params\])

Edit an object.

    /cgi-bin/index.cgi?a=edit&id=<id>

### URL Parameters

- id
- object\_id

The id of the object to edit.

## edit\_user

## home

- home($MINORIMPACT, \[\\%params\])

Display all the objects found by executing $params->{query}.  If query is not defined, 
pull a list of everything the user owns.  This action/page requires a currently
logged in user.

## index

- ::($MINORIMPACT, \\%params)

The main site page, what's displayed to the world.  By default, 

## search

Search the system application.

### URL parameters

- search

    A string to search for.  See [MinorImpact::Object::Search::parseSearchString()](./MinorImpact_Object_Search.md#parsesearchstring).

        # search for objects tagged with 'test' that contain the word 'poop'.
        /cgi-bin/index.cgi?a=search&search=poop%tag:test

## settings

## tags

Display a list of the current user's tags - or the tags for all public objects
owned by 'admin' users, if no user is currenly logged in.

## user

- ::user($MINORIMPACT, \\%params)

Display objects and information about a particular user.

### params

## viewHistory

- viewHistory()
- viewHistory( $field )
- viewHistory( $field, $value )

# AUTHOR

Patrick Gillan <pgillan@minorimpact.com>
