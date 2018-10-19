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

- "$field\_name\[>,<\]" => $value

    If you pass a random field name, MinorImpact will attempt to find object types
    with fields named $field\_name and values of $value.  If you don't specify an `object_type_id`,
    **you may get different types of objects back in the same list!**  This can be chaotic, so it's
    not recommended.

        # get all MinorImpact::entry objects published on the 10th.
        MinorImpact::Object::Search::search({ object_type_id => "MinorImpact::entry", publish_date => '2018-10-10' });

    If you append ">" or "<" to the field name, it will use that operator to 
    perform the comparison, rather than "=".

        # get all MinorImpact::entry objects published after the 10th.
        MinorImpact::Object::Search::search({ object_type_id => "MinorImpact::entry", "publish_date>" => '2018-10-10' });

- id\_only

    Return an array of object IDs, rather than complete objects.

        # get just the object IDs of dogs named 'Spot'.
        @object_ids = MinorImpact::Object::Search::search({query => {object_type_id => 'dog', name => "Spot", id_only => 1}});

- limit

    Return only `limit` items.  `search()` actually return `limit` + 1 results, which is a lame
    way of indicating that there are additional items (this is stupid and will probably change,
    hopefully for the better).
    DEFAULT: 10 if `page` is defined.

- name => $string

    Find objects named "$string".

        # find all objects named 'Ford'
        MinorImpact::Object::Search::search({ name => 'Ford' });

- object\_type\_id

    Return objects of only a particular type.  Can be the numeric id or the name.

        # get all MinorImpact::entry objects.
        @objects = MinorImpact::Object::Search::search({ object_type_id => "MinorImpact::entry" });

- page

    Skip to `page` of results.
    DEFAULT: 1 of `limit` is defined.

- public

    Limit search to only items parked 'public.'

        # find all public objects named 'Ford'
        MinorImpact::Object::Search::search({ name => 'Ford', public => 1 });

- sort => $sort

    If sort the results before they are returned.  If id\_only is true, then the
    list of IDs will come back sorted, which may not be useful.  Otherwise, the
    objects will be sorted in ascending order (if $sort > 0) or descending order
    if ($sort < 0) using the objects' [cmp()](./MinorImpact_Object.md#cmp) function.

        @objects = MinorImpact::Object::Search::search({ sort => 1 });

# AUTHOR

Patrick Gillan <pgillan@minorimpact.com>
