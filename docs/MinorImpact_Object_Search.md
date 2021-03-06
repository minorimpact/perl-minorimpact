# NAME

MinorImpact::Object::Search

# SYNOPSIS

# DESCRIPTION

# METHODS

## mergeQuery

- ::mergeQuery(\\%query, \\%params);

Merges the values from %query into $params->{query}.

## parseSearchString

- parseSearchString($string)
- parseSearchString(\\%params)

Parses $string and returns a %query hash pointer.

    $local_params->{query} = MinorImpact::Object::Search::parseSearchString("tag:foo tag:bar dust");
    # RESULT: $local_params->{query} = { tag => 'foo,bar', text => 'dust' };

## processQuery

- ::processQuery(\\%params);

Looks at $params->{query} and converts $params->{query}{search} into
the proper query hash values, merging whatever it finds with the 
current $params->{params}{query} values.

    $params->{query} = { page => 2, limit => 10, search => "tag:bar test", tag => "foo" };
    MinorImpact::Object::Search::parseSearchString($params);
    # RESULT: $params->{query} = { tag => 'foo,bar', text => 'test', page => 2, limit => 10 };

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
        @objects = MinorImpact::Object::Search::search({ 
              object_type_id => "MinorImpact::entry", 
              "publish_date>" => '2018-10-10' 
        });

- admin BOOLEAN

    Only return objects that belong to a user with admin rights.

        # get all public objects owned by an admin
        @objects = MinorImpact::Object::Search::search({ 
              admin => 1,
              public => 1,
        });

- child => \\&hash

    Further limit the results from your search to objects who's _children_ match
    the query parameters in \\&hash.

        # pull just owner who have a dodge.
        @car_owner = MinorImpact::Object::Search::search({
          object_type_id=>'owners',
          child => {
            object_type_id => 'car',
            make => 'Dodge'
          },
        });

- no\_child => \\&hash

    The opposite of "child": exclude objects who's children match
    \\&hash.

        # pull everyone by 'viper' owners
        @car_owner = MinorImpact::Object::Search::search({
          object_type_id=>'owners',
          no_child => {
            object_type_id => 'car',
            model => 'Viper'
          },
        });

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

#### result

A {result} hash pointer is added to `$params-`{query}> that contains
information about a successful search.

- count

    The total number of results found.

- more

    A boolean that simply indicates whether or not there are "more" results
    beyond the current set.

        if ($params->{query}{result}{more}) {
          print "<a href=/more">View more results</a>\n";
        }

- data

    A pointer to the array of objects or IDs returned from the search.

- sql

    The exact SQL statement that was executed.

# AUTHOR

Patrick Gillan <pgillan@minorimpact.com>
