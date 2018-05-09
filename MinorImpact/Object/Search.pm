package MinorImpact::Object::Search;

use strict;

use Digest::MD5 qw(md5 md5_hex);
use Data::Dumper;

use MinorImpact;
use MinorImpact::Util;
use Text::ParseWords;

sub parseSearchString {
    my $string = shift || return;

    my $params = {};
    if (ref($string) eq "HASH") {
        $params = $string;
        $string = $params->{query}{search} || $params->{query}{text};
    }

    $string = lc($string);
    $params->{query}{debug} .= 'MinorImpact::Object::Search::parseSearchString();';
    my @tags = extractTags(\$string);
    trim(\$string);
    foreach my $tag (@tags) {
        $params->{query}{tag} .= ",$tag";
    }
    $params->{query}{tag} =~s/^,//;

    #my $fields = extractFields(\$string);
    #trim(\$string);

    # This is confusing because the two strings do different things at different times, but
    #   generally the "search" string is what the user sees, when they type it into the
    #   search bar, and "text" is what's left when all the special sauce has be been
    #   extracted. "search" gets processed and obliterated, and "text" just becomes one of 
    #   the many search search parameters, along with "tag", "order" and "field=value" pairs.
    delete($params->{query}{search});
    $params->{query}{text} = $string;

    return $params;
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

    return $params;
}

sub search {
    my $params = shift || {};

    #MinorImpact::log('debug', "starting");

    my $local_params = cloneHash($params);

    return unless defined ($local_params->{query});
    $local_params->{query}{debug} .= "MinorImpact::Object::Search::search();";
    parseSearchString($local_params);

    my @ids = _search($local_params);
    # We'll sort them since somewone requested it, but it's kind of
    #   pointless without the whole object.
    @ids = sort @ids if ($params->{query}{sort});

    # There's no pagination or type_trees, since these are just
    #   IDs.  You need to have access to all the data to get
    #   fancy options.
    return @ids if ($params->{query}{id_only});

    my @objects;
    foreach my $id (@ids) {
        eval {
            my $object = new MinorImpact::Object($id);
            # This is where we limit what comes back to just what
            #   the current user has access to.  We may want to 
            #   override this in the future with an admin flag
            #   and an admin user.
            next unless ($object->validateUser($params));
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
    MinorImpact::log('debug', 'Paging');
    my $page = $params->{query}{page} || 1;
    my $limit = $params->{query}{limit} || ($page?10:0);

    if ($page && $limit) {
        @objects = splice(@objects, (($page - 1) * $limit), $limit + 1);
    }

    unless ($params->{query}{type_tree}) {
        #MinorImpact::log('debug', "ending");
        return @objects;
    }

    # Return a hash of arrays organized by type.
    my $objects;
    foreach my $object (@objects) {
        push(@{$objects->{$object->typeID()}}, $object);
    }
    #MinorImpact::log('debug', "ending");
    return $objects;
}

sub _search {
    my $params = shift || {};

    #MinorImpact::log('info', "starting");
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
        $w =~s/\s*and\s+//i;
        $where .= " AND $w";
        push (@fields, @{$query->{where_fields}});
    }

    # If I'm not looking for objects marked 'public', then I can only look for objects
    # owned by the current user. "security".
    unless ($query->{public}) {
        my $user = MinorImpact::user();
        if ($user) {
            $query->{user_id} = $user->id();
        } else {
            $query->{public} = 1;
        }
    }

    # Proces all the options.  I don't like that that process settings are mixed up with field/search data
    # but that's how I did it.
    # TODO: Go through all the code and separate the terms that define "how" the search should be handled from
    #  "what" we're searching for. 
    #MinorImpact::debug(1);
    foreach my $param (keys %$query) {
        MinorImpact::log('debug', "\$param='$param', \$query->{$param}='" . $query->{$param} . "'");
        next if ($param =~/^(from|id_only|sort|limit|page|debug|where|where_fields|child|no_child|select|type_tree)$/);
        next unless (defined($query->{$param}));
        MinorImpact::log('debug', "building query \$query->{$param}='" . $query->{$param} . "'");
        if ($param eq "name") {
            $where .= " AND object.name = ?",
            push(@fields, $query->{name});
        } elsif ($param eq "public") {
            $where .= " AND object.public = ?",
            push(@fields, ($query->{public}?1:0));
        } elsif ($param eq "object_type_id") {
            $from .= " JOIN object_type ON (object.object_type_id=object_type.id)" unless ($from =~/JOIN object_type/);
            if ($query->{object_type_id} =~/^[0-9]+$/) {
                $where .= " AND object_type.id=?";
            } else {
                $where .= " AND object_type.name=?";
            }
            push(@fields, $query->{object_type_id});
        } elsif ($param eq "user_id" || $param eq "user") {
            $where .= " AND object.user_id=?";
            push(@fields, $query->{user_id} || $query->{user});
        } elsif ($param eq "system") {
            $from .= " JOIN object_type ON (object.object_type_id=object_type.id)" unless ($from =~/JOIN object_type/);
            $where .= " AND object_type.system = ? ";
            push(@fields, $query->{system});
        } elsif ($param eq "tag") {
            my $tag_where;
            foreach my $tag (split(",", $query->{tag})) {
                $from .= " LEFT JOIN object_tag ON (object.id=object_tag.object_id)" unless ($from =~/JOIN object_tag/);
                if (!$tag_where) {
                    $tag_where = "SELECT object_id FROM object_tag WHERE name=?";
                } else {
                    $tag_where = "SELECT object_id FROM object_tag WHERE name=? AND object_id IN ($tag_where)";
                }
                push(@fields, $tag);
            }
            $where .= " AND object_tag.object_id IN ($tag_where)" if ($tag_where);
        } elsif ($param eq "description") {
            $where .= " AND object.description like ?";
            push(@fields, "\%$query->{description}\%");
        } elsif ($param eq "text" || $param eq "search") {
            my $text = $query->{text} || $query->{search};
            if ($text) {
                $from .= " LEFT JOIN object_text ON (object.id=object_text.object_id)" unless ($from =~/JOIN object_text/);
                $where .= " AND (object.name LIKE ? OR object_data.value LIKE ? OR object_text.value LIKE ?)";
                push(@fields, "\%$text\%");
                push(@fields, "\%$text\%");
                push(@fields, "\%$text\%");
            }
        } elsif ($query->{object_type_id}) {
            MinorImpact::log('debug', "Find fieldID for '$param', '" . $query->{object_type_id} . "'");

            my $object_field_id = MinorImpact::Object::fieldID($query->{object_type_id}, $param);
            #MinorImpact::log('debug', "\$object_field_id='$object_field_id'");
            $from .= " JOIN object_data as object_data$object_field_id ON (object.id=object_data$object_field_id.object_id)";
            $where .= " AND (object_data$object_field_id.object_field_id=? AND object_data$object_field_id.value=?)";
            push(@fields, $object_field_id);
            push(@fields, $query->{$param});
        } else {
            # At this point, assume the developer just specified a random field in one of his objects, and pull all the fields
            # with this name from all the objects in the system.
            MinorImpact::log('debug', "Find fieldIDs for '$param'");
            my $field_where;
            my @object_field_ids = MinorImpact::Object::fieldIDs($param);
            foreach my $object_field_id (@object_field_ids) {
                $from .= " LEFT JOIN object_data as object_data$object_field_id ON (object.id=object_data$object_field_id.object_id)";
                $field_where .= "(object_data$object_field_id.object_field_id=? AND object_data$object_field_id.value=?) OR ";
                push(@fields, $object_field_id);
                push(@fields, $query->{$param});
            }
            $field_where =~s/ OR $//;
            $where .=  "AND ($field_where)";
        }
    }
    #MinorImpact::debug(0);
    my $sql = "$select $from $where";
    MinorImpact::log('info', "sql='$sql', \@fields='" . join(',', @fields) . "' " . $query->{debug});


    my $objects;
    my $hash = md5_hex($sql);
    #$objects = MinorImpact::cache("search_$hash");

    unless ($objects) {
        $objects = $DB->selectall_arrayref($sql, {Slice=>{}}, @fields);
        MinorImpact::cache("search_$hash", $objects);
    }

    #MinorImpact::log('info', "ending");
    return map { $_->{id}; } @$objects;
}

1;
