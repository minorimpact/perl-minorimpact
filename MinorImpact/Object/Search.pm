package MinorImpact::Object::Search;

=head1 NAME

MinorImpact::Object::Search

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 METHODS

=cut

use strict;

use Digest::MD5 qw(md5 md5_hex);
use Data::Dumper;

use MinorImpact;
use MinorImpact::Util;
use Text::ParseWords;

=head2 mergeQuery

=over

=item ::mergeQuery(\%query, \%params);

=back

Merges the values from %query into $params->{query}.

=cut

sub mergeQuery {
    my $query = shift || return;
    my $params = shift || {};

    $params->{query}{tags} = [] unless (defined($params->{query}{tags}));
    $query->{tags} = [] unless (defined($query->{tags}));
    push(@{$params->{query}{tags}}, @{$query->{tags}});
    @{$params->{query}{tags}} = uniq(@{$params->{query}{tags}});

    my @tags = split(/,/, $query->{tag});
    $params->{query}{tag} = "," . $params->{query}{tag} unless ($params->{query}{tag} =~/^,/);
    foreach my $tag (@tags) {
        $params->{query}{tag} = $params->{query}{tag} . ",$tag" unless ($params->{query}{tag} =~/,$tag\b/);
    }
    $params->{query}{tag} =~s/^,//;

    foreach my $field (keys %{$query}) {
        next if ($field =~/^(tag|tags)$/);
        $params->{query}{$field} = $query->{$field};
    }
    return $params->{query};
}

=head2 parseSearchString

=over

=item parseSearchString($string)

=item parseSearchString(\%params)

=back

Parses $string and returns a %query hash pointer.

  $local_params->{query} = MinorImpact::Object::Search::parseSearchString("tag:foo tag:bar dust");
  # RESULT: $local_params->{query} = { tag => 'foo,bar', text => 'dust' };

=cut

sub parseSearchString {
    my $string = shift || return {};

    MinorImpact::log('debug', "starting");

    my $query = {};

    $query->{debug} = 'MinorImpact::Object::Search::parseSearchString();';

    my @tags = extractTags(\$string);

    $query->{tags} = \@tags;

    if (scalar(@tags)) {
        $query->{tag} = ',' . $query->{tag} unless ($query->{tag} =~/^,/);
        foreach my $tag (@tags) {
            $query->{tag} .= ",$tag" unless ($query->{tag} =~/,$tag\b/);
        }
        $query->{tag} =~s/^,//;
    }

    my $fields = extractFields(\$string);
    if (scalar(keys(%$fields))) {
        foreach my $field_name (keys %$fields) {
            my $field_value = $fields->{$field_name};
            MinorImpact::log('debug', "$field_name='$field_value'");
            if ($field_name eq 'object_type_id') {
                $field_value = MinorImpact::Object::typeID($field_value);
            }
            $query->{$field_name} = $field_value;
        }
    }

    trim(\$string);
    # This is confusing because the two strings do different things at different times, but
    #   generally the "search" string is what the user sees, when they type it into the
    #   search bar, and "text" is what's left when all the special sauce has be been
    #   extracted. "search" gets processed and obliterated, and "text" just becomes one of 
    #   the many search search parameters, along with "tag", "order" and "field=value" pairs.
    delete($query->{search});
    MinorImpact::log('debug', "\$string='$string'");
    if ($string) {
        if ($query->{text}) {
            $query->{text} .= " $string";
        } else {
            $query->{text} = $string;
        }
    }

    MinorImpact::log('debug', "ending");
    return $query;
    # Working on a more complicated search mechanism, uncomment the previous return to make it
    # active.
    my @ors;
    my @ands;
    my $string2 = $string;
    my @parsed = parse_line('\s+', 0,  $string2);
    for (my $i = 0; $i<scalar(@parsed); $i++) {
        my $token = $parsed[$i];
        next if ($token eq "and");
        if ( $i < (scalar(@parsed) - 2) && $parsed[$i+1] eq 'or') {
            push(@ors, $parsed[$i], $parsed[$i + 2]);
            undef($parsed[$i]);
            undef($parsed[$i+1]);
            undef($parsed[$i+2]);
            next;
        }
        if (defined($token)) {
            push(@ands, $token);
        }
    }
    #MinorImpact::log('debug', "\@ands='" . join(",", @ands) . "'");
    #MinorImpact::log('debug', "\@ors='" . join(",", @ors) . "'");

    #my @tags = extractTags(\$string);
    #foreach my $tag (@tags) {
    #    $params->{tag} .= "$tag,";
    #}
    #$params->{tag} =~s/,$//;
    #trim(\$string);

    MinorImpact::log('debug', "ending");
    return $query;
}

=head2 processQuery

=over

=item ::processQuery(\%params);

=back

Looks at $params->{query} and converts $params->{query}{search} into
the proper query hash values, merging whatever it finds with the 
current $params->{params}{query} values.

  $params->{query} = { page => 2, limit => 10, search => "tag:bar test", tag => "foo" };
  MinorImpact::Object::Search::parseSearchString($params);
  # RESULT: $params->{query} = { tag => 'foo,bar', text => 'test', page => 2, limit => 10 };

=cut

sub processQuery {
    my $params = shift || return;

    MinorImpact::log('debug', "starting");

    my $query = {};
    if (ref($params) eq "HASH" && defined($params->{query})) {
        $query = $params->{query};
    }

    my $new_query = parseSearchString($params->{query}{search}) if (defined($params->{query}{search}) && $params->{query}{search});
    delete($params->{query}{search});
    mergeQuery($new_query, $params);
    MinorImpact::log('debug', "ending");
    return $params->{query};
}

=head2 search

=over

=item ::search(\%params)

=back

Search for objects.

  # get a list of public 'car' objects for a particular users.
  @objects = MinorImpact::Object::Search::search({query => {object_type_id => 'car',  public => 1, user_id => $user->id() } });

=head3 params

=head4 query

=over

=item "$field_name[>,<]" => $value

If you pass a random field name, MinorImpact will attempt to find object types
with fields named $field_name and values of $value.  If you don't specify an C<object_type_id>,
B<you may get different types of objects back in the same list!>  This can be chaotic, so it's
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

=item admin BOOLEAN

Only return objects that belong to a user with admin rights.

  # get all public objects owned by an admin
  @objects = MinorImpact::Object::Search::search({ 
        admin => 1,
        public => 1,
  });

=item id_only

Return an array of object IDs, rather than complete objects.

  # get just the object IDs of dogs named 'Spot'.
  @object_ids = MinorImpact::Object::Search::search({query => {object_type_id => 'dog', name => "Spot", id_only => 1}});

=item limit

Return only C<limit> items.  C<search()> actually return C<limit> + 1 results, which is a lame
way of indicating that there are additional items (this is stupid and will probably change,
hopefully for the better).
DEFAULT: 10 if C<page> is defined.

=item name => $string

Find objects named "$string".

  # find all objects named 'Ford'
  MinorImpact::Object::Search::search({ name => 'Ford' });

=item object_type_id

Return objects of only a particular type.  Can be the numeric id or the name.

  # get all MinorImpact::entry objects.
  @objects = MinorImpact::Object::Search::search({ object_type_id => "MinorImpact::entry" });

=item page

Skip to C<page> of results.
DEFAULT: 1 of C<limit> is defined.

=item public

Limit search to only items parked 'public.'

  # find all public objects named 'Ford'
  MinorImpact::Object::Search::search({ name => 'Ford', public => 1 });

=item sort => $sort

If sort the results before they are returned.  If id_only is true, then the
list of IDs will come back sorted, which may not be useful.  Otherwise, the
objects will be sorted in ascending order (if $sort > 0) or descending order
if ($sort < 0) using the objects' L<cmp()|MinorImpact::Object/cmp> function.

  @objects = MinorImpact::Object::Search::search({ sort => 1 });

=back

=head4 result

A {result} hash pointer is added to C<$params->{query}> that contains
information about a successful search.

=over

=item count

The total number of results found.

=item more

A boolean that simply indicates whether or not there are "more" results
beyond the current set.

  if ($params->{query}{result}{more}) {
    print "<a href=/more">View more results</a>\n";
  }

=item data

A pointer to the array of objects or IDs returned from the search.

=item sql

The exact SQL statement that was executed.

=back

=cut

sub search {
    my $params = shift || {};

    MinorImpact::log('debug', "starting");

    #my $local_params = cloneHash($params);

    return unless defined ($params->{query});
    $params->{query}{debug} .= "MinorImpact::Object::Search::search();";
    processQuery($params);

    my $page = $params->{query}{page} || ($params->{query}{limit}?1:0);
    my $limit = $params->{query}{limit} || ($params->{query}{page}?10:0);

    # Set these to the value we actually ended up using so the caller
    #   is working with matching values.
    $params->{query}{page} = $page;
    $params->{query}{limit} = $limit;
    my @ids = _search($params);

    $params->{query}{result}{count} = scalar(@ids);

    if ($params->{query}{id_only}) {
        # We'll sort them since someone requested it, but it's kind of
        #   pointless without the whole object.
        @ids = sort @ids if ($params->{query}{sort});

        if ($page && $limit) {
            @ids = splice(@ids, (($page - 1) * $limit), $limit + 1);
        }

        if ($limit && scalar(@ids) > $limit) {
            $params->{query}{result}{more} = 1;
            pop(@ids);
        }
        $params->{query}{result}{data} = \@ids;

        return @ids;
    }

    my @objects;
    foreach my $id (@ids) {
        eval {
            my $object = new MinorImpact::Object($id);
            # This is where we limit what comes back to just what
            #   the current user has access to.  We may want to 
            #   override this in the future with an admin flag
            #   and an admin user.
            next unless ($object->validUser($params));
            if (defined($params->{query}{child})) {
                my @children = $object->getChildren({ query => { %{$params->{query}{child}}, id_only => 1 } });
                push(@objects, $object) if (scalar(@children));
            } elsif (defined($params->{query}{no_child})) {
                MinorImpact::log('debug', "NO CHILD: $id");
                my @children = $object->getChildren({ query => { %{$params->{query}{no_child}}, id_only => 1 } });
                push(@objects, $object) unless (scalar(@children));
            } else {
                push(@objects, $object);
            }
        };
        MinorImpact::log('notice', $@) if ($@);
    }
    if (defined($params->{query}{sort}) && $params->{query}{sort} != 0) {
        MinorImpact::log('debug', 'sorting');
        @objects = sort {$a->cmp($b); } @objects;
        if ($params->{query}{sort} < 0) {
            @objects = reverse @objects;
        }
    }

    if ($page && $limit) {
        @objects = splice(@objects, (($page - 1) * $limit), $limit + 1);
    }

    if ($limit && scalar(@objects) > $limit) {
        $params->{query}{result}{more} = 1;
        pop(@objects);
    }
    $params->{query}{result}{data} = \@objects;

    unless ($params->{query}{type_tree}) {
        MinorImpact::log('debug', "ending");
        return @objects;
    }

    # Return a hash of arrays organized by type.
    my $objects;
    foreach my $object (@objects) {
        push(@{$objects->{$object->typeID()}}, $object);
    }
    MinorImpact::log('debug', "ending");
    return $objects;
}

sub _search {
    my $params = shift || {};

    MinorImpact::log('debug', "starting");
    my $DB = MinorImpact::db();

    my $query = $params->{query}; # || $params;
    $query->{object_type_id} = $query->{object_type} if ($query->{object_type} && !$query->{object_type_id});
    my $select = "SELECT DISTINCT(object.id)";
    my $from   = "FROM object LEFT JOIN object_data AS object_data ON (object.id=object_data.object_id) LEFT JOIN object_field ON (object_field.id=object_data.object_field_id)";
    my $where  = "WHERE object.id > 0";
    my @fields;

    # Let the caller write their own SQL.
    $select .= $query->{select} if ($query->{select});
    $from .= $query->{from} if ($query->{from});
    if ($query->{where}) {
        my $w = $query->{where};
        $w =~s/^\s*and\s+//i;
        $where .= " AND $w";
        push (@fields, @{$query->{where_fields}});
    }

    # If I'm not looking for objects marked 'public', then I can only look for objects
    # owned by the current user. "security".
    unless ($query->{public}) {
        my $user = MinorImpact::user();
        unless ($user->isAdmin()) {
            if ($user) {
                $query->{user_id} = $user->id();
            } else {
                $query->{public} = 1;
            }
        }
    }

    if (defined($query->{tags}) && scalar(@{$query->{tags}})) {
        my $tag_where;
        foreach my $tag (@{$query->{tags}}) {
            $from .= " LEFT JOIN object_tag ON (object.id=object_tag.object_id)" unless ($from =~/JOIN object_tag /);
            if (!$tag_where) {
                $tag_where = "SELECT object_id FROM object_tag WHERE name=?";
            } else {
                $tag_where = "SELECT object_id FROM object_tag WHERE name=? AND object_id IN ($tag_where)";
            }
            push(@fields, $tag);
        }
        $where .= " AND object_tag.object_id IN ($tag_where)" if ($tag_where);
    }

    # Proces all the options.  I don't like that that process settings are mixed up with field/search data
    # but that's how I did it.
    # TODO: Go through all the code and separate the terms that define "how" the search should be handled from
    #  "what" we're searching for. 
    #MinorImpact::debug(1);
    foreach my $param (keys %$query) {
        next if ($param =~/^(from|id_only|sort|limit|page|debug|where|where_fields|child|no_child|result|search|select|tags|type_tree)$/);
        MinorImpact::log('debug', "\$param='$param', \$query->{$param}='" . $query->{$param} . "'");
        next unless (defined($query->{$param}));
        MinorImpact::log('debug', "building query \$query->{$param}='" . $query->{$param} . "'");
        if ($param eq "name") {
            $where .= " AND object.name = ?",
            push(@fields, $query->{name});
        } elsif ($param eq "admin") {
            $from .= " JOIN user ON (object.user_id=user.id)" unless ($from =~/JOIN user /);
            $where .= " AND user.admin = ?";
            push(@fields, ($query->{admin}?1:0));
        } elsif ($param eq "public") {
            $where .= " AND object.public = ?",
            push(@fields, ($query->{public}?1:0));
        } elsif ($param eq "object_type_id") {
            $from .= " JOIN object_type ON (object.object_type_id=object_type.id)" unless ($from =~/JOIN object_type /);
            if ($query->{object_type_id} =~/^[0-9]+$/) {
                $where .= " AND object_type.id=?";
            } else {
                $where .= " AND object_type.name=?";
            }
            push(@fields, $query->{object_type_id});
        } elsif ($param eq "user_id" || $param eq "user") {
            $where .= " AND object.user_id=?";
            push(@fields, $query->{user_id} || $query->{user});
        } elsif ($param eq "readonly") {
            $from .= " JOIN object_type ON (object.object_type_id=object_type.id)" unless ($from =~/JOIN object_type /);
            $where .= " AND object_type.readonly = ? ";
            push(@fields, $query->{readonly});
        } elsif ($param eq "system") {
            $from .= " JOIN object_type ON (object.object_type_id=object_type.id)" unless ($from =~/JOIN object_type /);
            $where .= " AND object_type.system = ? ";
            push(@fields, $query->{system});
        } elsif ($param eq "tag") {
            my $tag_where;
            foreach my $tag (extractTags($params->{tag})) {
                if ($tag) {
                    $from .= " LEFT JOIN object_tag ON (object.id=object_tag.object_id)" unless ($from =~/JOIN object_tag /);
                    if (!$tag_where) {
                        $tag_where = "SELECT object_id FROM object_tag WHERE name=?";
                    } else {
                        $tag_where = "SELECT object_id FROM object_tag WHERE name=? AND object_id IN ($tag_where)";
                    }
                    push(@fields, $tag);
                }
            }
            $where .= " AND object_tag.object_id IN ($tag_where)" if ($tag_where);
        } elsif ($param eq "description") {
            $where .= " AND object.description like ?";
            push(@fields, "\%$query->{description}\%");
        } elsif ($param eq "text" || $param eq "search") {
            my $text = $query->{text} || $query->{search};
            if ($text) {
                $from .= " LEFT JOIN object_text ON (object.id=object_text.object_id)" unless ($from =~/JOIN object_text /);
                $where .= " AND (object.name LIKE ? OR object_data.value LIKE ? OR object_text.value LIKE ?)";
                push(@fields, "\%$text\%");
                push(@fields, "\%$text\%");
                push(@fields, "\%$text\%");
            }
        } elsif ($query->{object_type_id}) {
            my $value = $query->{$param};
            my $operator = "=";
            if ($param =~s/\>$//) { $operator = ">"; } 
            elsif ($param =~s/\<$//) { $operator = "<"; } 
            elsif ($param =~s/\=$//) { }

            MinorImpact::log('debug', "Find fieldID for '$param', '" . $query->{object_type_id} . "'");

            my $object_field_id = MinorImpact::Object::fieldID($query->{object_type_id}, $param);
            #MinorImpact::log('debug', "\$object_field_id='$object_field_id'");
            next unless ($object_field_id);
            $from .= " JOIN object_data as object_data$object_field_id ON (object.id=object_data$object_field_id.object_id)" unless ($from =~/JOIN object_data$object_field_id /);
            $where .= " AND (object_data$object_field_id.object_field_id = ? AND object_data$object_field_id.value $operator ?)";
            push(@fields, $object_field_id);
            push(@fields, $value);
        } else {
            # At this point, assume the developer just specified a random field in one of his objects, and pull all the fields
            # with this name from all the objects in the system.
            MinorImpact::log('debug', "Find fieldIDs for '$param'");
            my $value = $query->{$param};
            my $operator = "=";
            if ($param =~s/\>$//) { $operator = ">"; } 
            elsif ($param =~s/\<$//) { $operator = "<"; } 
            elsif ($param =~s/\=$//) { }

            my $field_where;
            my @object_field_ids = MinorImpact::Object::fieldIDs($param);
            foreach my $object_field_id (@object_field_ids) {
                $from .= " LEFT JOIN object_data as object_data$object_field_id ON (object.id=object_data$object_field_id.object_id)";
                $field_where .= "(object_data$object_field_id.object_field_id=? AND object_data$object_field_id.value $operator ?) OR ";
                push(@fields, $object_field_id);
                push(@fields, $value);
            }
            $field_where =~s/ OR $//;
            $where .=  "AND ($field_where)" if ($field_where);
        }
    }

    #MinorImpact::debug(1);
    my $sql = "$select $from $where";
    MinorImpact::log('debug', "sql='$sql', \@fields='" . join(',', @fields) . "' " . $query->{debug});
    #MinorImpact::debug(0);


    my $objects;
    my $hash = md5_hex($sql);
    #$objects = MinorImpact::cache("search_$hash");

    unless ($objects) {
        $objects = $DB->selectall_arrayref($sql, {Slice=>{}}, @fields);
        MinorImpact::cache("search_$hash", $objects);
    }

    $query->{result}{sql} = $sql;

    MinorImpact::log('debug', "ending");
    return map { $_->{id}; } @$objects;
}

=head1 AUTHOR

Patrick Gillan <pgillan@minorimpact.com>

=cut

1;
