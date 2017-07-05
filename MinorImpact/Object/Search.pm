package MinorImpact::Object::Search;

use Data::Dumper;

use MinorImpact;
use MinorImpact::Util;

sub parseSearchString {
    my $string = shift || return;

    my $params = {};
    if (ref($string) eq "HASH") {
        $params = $string;
        $string = $params->{search} || $params->{text};
    }

    $params->{debug} .= 'MinorImpact::Object::Search::parseSearchString();';
    #MinorImpact::log(8, "before extractTags \$string='$string'");
    my @tags = extractTags(\$string);
    #MinorImpact::log(8, "after extractTags \$string='$string'");
    foreach my $tag (@tags) {
        $params->{tag} .= "$tag,";
    }
    $params->{tag} =~s/,$//;
    trim(\$string);

    # This is confusing because the two strings do different things at different times, but
    #   generally the "search" string is what the user sees, when they type it into the
    #   search bar, and "text" is what's left when all the special sauce has be been
    #   extracted: tags, field=value pairs, etc.
    delete($params->{search});
    $params->{text} = $string;
    return $params;

}

sub search {
    my $params = shift || {};

    #MinorImpact::log(7, "starting");

    my $local_params = cloneHash($params);

    $local_params->{debug} .= "MinorImpact::Object::Search::search();";
    parseSearchString($local_params);

    my @ids = _search($local_params);
    # We'll sort them since somewone requested it, but it's kind of
    #   pointless without the whole object.
    @ids = sort @ids if ($params->{sort});

    # There's no pagination or type_trees, since these are just
    #   IDs.  You need to have access to all the data to get
    #   fancy options.
    return @ids if ($params->{id_only});


    my @objects;
    foreach my $id (@ids) {
        #MinorImpact::log(8, "\$id=" . $id);
        eval {
            my $object = new MinorImpact::Object($id);
            # This is where we limit what comes back to just what
            #   the current user has access to.  We may want to 
            #   override this in the future with an admin flag
            #   and an admin user.
            push(@objects, $object) if ($object->validateUser());
        };
    }
    if ($params->{sort}) {
        @objects = sort {$a->cmp($b); } @objects;
    }
    my $page = $params->{page} || 0;
    my $limit = $params->{limit} || ($page?10:0);

    if ($page && $limit) {
        @objects = splice(@objects, (($page - 1) * $limit), $limit);
    }

    unless ($params->{type_tree}) {
        #MinorImpact::log(7, "ending");
        return @objects;
    }

    # Return a hash of arrays organized by type.
    my $objects;
    foreach my $object (@objects) {
        push(@{$objects->{$object->typeID()}}, $object);
    }
    #MinorImpact::log(7, "ending");
    return $objects;
}

sub _search {
    my $params = shift || {};

    #MinorImpact::log(7, "starting");
    my $DB = MinorImpact::getDB();

    $params->{object_type_id} = $params->{object_type} if ($params->{object_type} && !$params->{object_type_id});
    my $select = "SELECT DISTINCT(object.id) ";
    my $from   = "FROM object JOIN object_type ON (object.object_type_id=object_type.id) LEFT JOIN object_tag ON (object.id=object_tag.object_id) LEFT JOIN object_data ON (object.id=object_data.object_id) LEFT JOIN object_text ON (object.id=object_text.object_id) JOIN object_field ON (object_field.id=object_data.object_field_id) ";
    my $where  = "WHERE object.id > 0 ";
    my @fields;

    $select .= $params->{select} if ($params->{select});
    $from .= $params->{from} if ($params->{from});
    if ($params->{where}) {
        my $w = $params->{where};
        $w =~s/\s*and\s+//i;
        $where .= " AND $w";
        push (@fields, @{$params->{where_fields}});
    }

    foreach my $param (keys %$params) {
        next if ($param =~/^(id_only|sort|limit|page|debug|where|where_fields)$/);
        next unless (defined($params->{$param}));
        #MinorImpact::log(8, "building query \$params->{$param}='" . $params->{$param} . "'");
        if ($param eq "name") {
            $where .= " AND object.name = ?",
            push(@fields, $params->{name});
        } elsif ($param eq "object_type_id") {
            if ($params->{object_type_id} =~/^[0-9]+$/) {
                $where .= " AND object_type.id=?";
            } else {
                $where .= " AND object_type.name=?";
            }
            push(@fields, $params->{object_type_id});
        } elsif ($param eq "user_id") {
            $where .= " AND object.user_id=?";
            push(@fields, $params->{user_id});
        } elsif ($param eq "tag") {
            my $tag_where;
            foreach my $tag (split(",", $params->{tag})) {
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
            push(@fields, "\%$params->{description}\%");
        } elsif ($param eq "text" || $param eq "search") {
            my $text = $params->{text} || $params->{search};
            if ($text) {
                $where .= " AND (object.name LIKE ? OR object_data.value LIKE ? OR object_text.value LIKE ?)";
                push(@fields, "\%$text\%");
                push(@fields, "\%$text\%");
                push(@fields, "\%$text\%");
            }
        } elsif ($params->{object_type_id}) {
            # If we specified a particular type of object to look for, then we can query
            # by arbitrary fields. If we didn't limit the object type, and just searched by field names, the results could be... chaotic.
            #MinorImpact::log(8, "trying to get a field id for '$param'");
            my $object_field_id = MinorImpact::Object::fieldID($params->{object_type_id}, $param);
            if ($object_field_id) {
                $from .= "JOIN object_data AS object_data$object_field_id ON (object.id=object_data$object_field_id.object_id) ";
                $where .= " AND (object_data$object_field_id.object_field_id=? AND object_data$object_field_id.value=?)";
                push(@fields, $object_field_id);
                push(@fields, $params->{$param});
            }
        }
    }

    my $sql = "$select $from $where";
    MinorImpact::log(3, "sql='$sql', \@fields='" . join(',', @fields) . "' " . $params->{debug});

    my $objects = $DB->selectall_arrayref($sql, {Slice=>{}}, @fields);

    #MinorImpact::log(7, "ending");
    return map { $_->{id}; } @$objects;
}

1;
