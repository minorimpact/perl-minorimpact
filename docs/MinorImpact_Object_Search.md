# NAME

MinorImpact::Object::Search

# SYNOPSIS

# DESCRIPTION

# METHODS

## search

- ::search(\\%params)

Search for objects.

    # get a list of public 'car' objects for a particular users.
    @objects = MinorImpact::Object::Search::search({query => {object_type_id => 'car',  public => 1, user_id => $user->id() } });

### params

#### query

- id\_only

    Return an array of object IDs, rather than complete objects.

        # get just the object IDs of dogs named 'Spot'.
        @object_ids = MinorImpact::Object::Search::search({query => {object_type_id => 'dog', name => "Spot", id_only => 1}});

- limit

    Return only `limit` items.  `search()` actually return `limit` + 1 results, which is a lame
    way of indicating that there are additional items (this is stupid and will probably change,
    hopefully for the better).
    DEFAULT: 10 if `page` is defined.

- page

    Skip to `page` of results.
    DEFAULT: 1 of `limit` is defined.

# AUTHOR

Patrick Gillan <pgillan@minorimpact.com>
