package MinorImpact::Object;

use Data::Dumper;
use JSON;
use Text::Markdown 'markdown';

use MinorImpact;
use MinorImpact::Util;
use MinorImpact::Object::Field;

my $OBJECT_CACHE;

sub new {
    my $package = shift || return;
    my $id = shift || return;

    #MinorImpact::log(7, "starting(" . $id . ")");
    my $DB = MinorImpact::getDB();
    my $object;

    return $OBJECT_CACHE->{$id} if ($OBJECT_CACHE->{$id});

    eval {
        my $type_name;
        if (ref($id) eq "HASH") {
            my $data = $DB->selectrow_hashref("SELECT name FROM object_type ot WHERE ot.id=?", undef, ($id->{type_id})) || die $MinorImpact::SELF->{DB}->errstr;
            $type_name = $data->{name}; 
        } else {
            my $data = $DB->selectrow_hashref("SELECT ot.name FROM object o, object_type ot WHERE o.object_type_id=ot.id AND o.id=?", undef, ($id)) || die $DB->errstr;
            $type_name = $data->{name};
        }
        #MinorImpact::log(7, "trying to create new '$type_name' with id='$id'");
        $object = $type_name->new($id) if ($type_name);
    };
    MinorImpact::log(1, "id='$id',error:$@") if ($@);
    if ($@ =~/^error:/) {
        my $error = $@;
        $error =~s/ at \/.*$//;
        $error =~s/^error://;
        die $error;
    }
    unless ($object) {
        $object = MinorImpact::Object::_new($package, $id);
    }
    #MinorImpact::log(8, "\$object doesn't exist") unless ($object);
    #MinorImpact::log(7, "ending($id)");

    $OBJECT_CACHE->{$object->id()} = $object if ($object);
    return $object;
}

sub _new {
    my $package = shift;
    my $params = shift;

    my $self = {};
    bless($self, $package);

    #MinorImpact::log(7, "starting(" . $params . ")");
    #MinorImpact::log(8, "package='$package'");
    my $type_name = lc($package);
    if ($type_name && !$params->{type_id}) {
        $params->{type_id} = type_id($type_name);
    }
    $self->{DB} = MinorImpact::getDB() || die;
    $self->{CGI} = MinorImpact::getCGI() || die;

    my $object_id;
    if (ref($params) eq 'HASH') {
        #MinorImpact::log(8, "ref(\$params)='" . ref($params) . "'");
        my $user_id = $params->{'user_id'} || $MinorImpact::SELF->getUser()->id();
        die "error:invalid name" unless ($params->{name});
        die "error:invalid user id" unless ($user_id);
        die "error:invalid type id" unless ($params->{type_id});
        my $data = $self->{DB}->selectall_arrayref("select * from object_field where object_type_id=?", {Slice=>{}}, ($params->{type_id}));
        foreach my $row (@$data) {
            my $field_name = $row->{name};
            #MinorImpact::log(8, "field_name='$field_name'");
            if ((!defined($params->{$field_name}) || !$params->{$field_name}) && $row->{required}) {
                MinorImpact::log(3, "$field_name cannot be blank");
                die "$field_name cannot be blank";
            }   
        }
        $self->{DB}->do("INSERT INTO object (name, user_id, description, object_type_id, create_date) VALUES (?, ?, ?, ?, NOW())", undef, ($params->{'name'}, $user_id, $params->{'description'}, $params->{type_id})) || die("Can't add new object:" . $self->{DB}->errstr);
        $object_id = $self->{DB}->{mysql_insertid};
        unless ($object_id) {
            MinorImpact::log(3, "Couldn't insert new object record");
            die "Couldn't insert new object record";
        }
        foreach my $row (@$data) {
            my $field_name = $row->{name};
            my $field_type = $row->{type};
            #MinorImpact::log(8, "field_name/field_type='$field_name/$field_type'");
            if (defined $params->{$field_name}) {
                #MinorImpact::log(8, "\$params->{$field_name} defined, = '" . $params->{$field_name} . "'");
                if ($field_type eq 'boolean') {
                    $self->{DB}->do("insert into object_data(object_id, object_field_id, value) values (?, ?, ?)", undef, ($object_id, $row->{id}, 1)) || die $self->{DB}->errstr;
                } else {
                    foreach my $value (split(/\0/, $params->{$field_name})) {
                        #MinorImpact::log(8, "$field_name='$value'");
                        if ($field_type =~/text$/ || $field_type =~/url$/) {
                            $self->{DB}->do("insert into object_text(object_id, object_field_id, value) values (?, ?, ?)", undef, ($object_id, $row->{id}, $value)) || die $self->{DB}->errstr;
                        } else {
                            $self->{DB}->do("insert into object_data(object_id, object_field_id, value) values (?, ?, ?)", undef, ($object_id, $row->{id}, $value)) || die $self->{DB}->errstr;
                        }
                    }
                }
            } elsif ($field_type eq 'boolean') {
                $self->{DB}->do("insert into object_data(object_id, object_field_id, value) values (?, ?, ?)", undef, ($object_id, $row->{id}, 0)) || die $self->{DB}->errstr;
            }
        }

        if ($params->{tags}) {
            foreach my $tag (parseTags($params->{tags})) {
                $self->{DB}->do("INSERT INTO object_tag(object_id, name) VALUES (?, ?)", undef, ($object_id, $tag));
            }
        }
    } elsif ($params =~/^\d+$/) {
        $object_id = $params;
    } else {
        $object_id = $self->{CGI}->param("id") || $MinorImpact::SELF->redirect('index.cgi');
    }

    $self->_reload($object_id);

    #MinorImpact::log(7, "ending(" . $self->id() . ")");
    return $self;
}

sub back {
    my $self = shift || return;
    
    my $script_name = MinorImpact::scriptName();
    return "$script_name";
}

sub id { my $self = shift || return; return $self->{data}->{id}; }
sub name { my $self = shift || return; return $self->get('name'); }
sub user_id { my $self = shift || return; return $self->get('user_id'); }   

sub selectList {
    my $self = shift || return;
    my $params = shift || {};

    #MinorImpact::log(7, "starting");
    my $local_params = cloneHash($params);
    if (ref($self) eq 'HASH') {
        $local_params = cloneHash($self);
        if ($params->{selected}) {
            $self = new MinorImpact::Object($params->{selected});
            $local_params->{user_id} = $self->user_id() if ($self && !$local_params->{user_id});
        } else {
            undef $self;
        }
    } elsif (ref($self)) {
        $local_params->{user_id} = $self->user_id() unless ($local_params->{user_id});
        $local_params->{selected} = $self->id() unless ($local_params->{selected});
    }

    my $select = "<select id='$local_params->{fieldname}' name='$local_params->{fieldname}'";
    if ($local_params->{duplicate}) {
        $select .= " onchange='duplicateRow(this);'";
    }
    $select .= ">\n";
    $select .= "<option></option>\n" unless ($local_params->{required});
    $local_params->{sort} = 1;
    my @objects = search($local_params);
    foreach my $object (@objects) {
        $select .= "<option value='" . $object->id() . "'";
        if ($local_params->{selected} && $local_params->{selected} == $object->id()) {
            $select .= " selected";
        }
        $select .= ">" . $object->name() . "</option>\n";
    }
    $select .= "</select>\n";
    #MinorImpact::log(7, "ending");
    return $select;
}

sub get {
    my $self = shift || return;
    my $name = shift || return;
    my $params = shift || {};

    my @values;
    #MinorImpact::log(7, "starting(" . $self->id() . ")");
    if (defined($self->{data}->{$name})) {
       return $self->{data}->{$name};
    }
    if (defined($self->{object_data}->{$name})) {
        my $field = $self->{object_data}->{$name};
        my @value = $self->{object_data}->{$name}->value();
        #MinorImpact::log(8,"$name='" . join(",", @value) . "'");
        foreach my $value (@value) {
            if ($params->{markdown}) {
                $value =  markdown($value);
            }
            push(@values, $value);
        }
        if ($field->isArray()) {
            return @values;
        }
        return $values[0];
    }
}   

sub validateFields {
    my $fields = shift;
    my $params = shift;

    #if (!$fields) {
    #   dumper($fields);
    #}
    #if (!$params) {
    #   dumper($params);
    #}

    die "No fields to validate." unless ($fields);
    die "No parameters to validate." unless($params);

    foreach my $field_name (keys %$params) {  
        my $field = $fields->{$field_name};
        next unless ($field);
        $field->validate($params->{$field_name});
    }
}

sub update {
    my $self = shift || return;
    my $params = shift || return;

    #MinorImpact::log(7, "starting(" . $self->id() . ")");
    $self->{DB}->do("UPDATE object SET name=? WHERE id=?", undef, ($params->{'name'}, $self->id())) if ($params->{name});
    $self->{DB}->do("UPDATE object SET description=? WHERE id=?", undef, ($params->{'description'}, $self->id())) if (defined($params->{description}));
    $self->log(1, $self->{DB}->errstr) if ($self->{DB}->errstr);

    my $fields = $self->fields();
    #print "Content-type: text/html\n\n";
    #dumper($fields);
    #dumper($params);;
    validateFields($fields, $params);

    foreach my $field_name (keys %$params) {
        my $field = $fields->{$field_name};
        next unless ($field);
        my $field_type = $field->type();
        if (defined $params->{$field_name}) {
            $self->{DB}->do("delete from object_data where object_id=? and object_field_id=?", undef, ($self->id(), $field->get('object_field_id'))) || die $self->{DB}->errstr;
            $self->{DB}->do("delete from object_text where object_id=? and object_field_id=?", undef, ($self->id(), $field->get('object_field_id'))) || die $self->{DB}->errstr;
            foreach my $value (split(/\0/, $params->{$field_name})) {
                if ($field_type =~/text$/ || $field_type eq 'url') {
                    $self->{DB}->do("insert into object_text(object_id, object_field_id, value, create_date) values (?, ?, ?, NOW())", undef, ($self->id(), $field->get('object_field_id'), $value)) || die $self->{DB}->errstr;
                } else {
                    #MinorImpact::log(8, "$field_name='$value'");
                    #MinorImpact::log(8, "insert into object_data(object_id, object_field_id, value, create_date) values (?, ?, ?, NOW()) (" . $self->id() . ", " . $field->get('object_field_id') . ", $value)");
                    $self->{DB}->do("insert into object_data(object_id, object_field_id, value, create_date) values (?, ?, ?, NOW())", undef, ($self->id(), $field->get('object_field_id'), $value)) || die $self->{DB}->errstr;
                }
            }
        }
    }

    foreach $param (keys %$params) {
        if ($param =~/^tags$/) {
            $self->{DB}->do("DELETE FROM object_tag WHERE object_id=?", undef, ($self->id()));
            MinorImpact::log(1, $self->{DB}->errstr) if ($self->{DB}->errstr);
            foreach my $tag (split(/\0/, $params->{$param})) {
                foreach my $tag (parseTags($tag)) {
                    next unless ($tag);
                    $self->{DB}->do("INSERT INTO object_tag (name, object_id) VALUES (?,?)", undef, ($tag, $self->id())) || die("Can't add object tag:" . $self->{DB}->errstr);
                }
            }
        }
    }
    $self->_reload();
    #MinorImpact::log(7, "ending");
    return;
}

sub fields {
    my $self = shift || return;

    my $object_type_id;
    if (ref($self) eq "HASH") {
        $object_type_id = $self->{object_type_id};
    } elsif (ref($self)) {
        return $self->{object_data} if ($self->{object_data});
        $object_type_id = $self->type_id();
    } else {
        $object_type_id = $self;
    }

    die "No type_id defined\n" unless ($object_type_id);

    my $fields;
    my $DB = MinorImpact::getDB();
    my $data = $DB->selectall_arrayref("select * from object_field where object_type_id=?", {Slice=>{}}, ($object_type_id)) || die $DB->errstr;
    foreach my $row (@$data) {
        #MinorImpact::log(8, $row->{name});
        $fields->{$row->{name}} = new MinorImpact::Object::Field($row);
    }
    return $fields;
}

sub type_id {
    my $self = shift || return;

    return MinorImpact::Object::typeID($self);
}

sub typeID {
    my $self = shift || return;

    #MinorImpact::log(7, "starting");
    my $object_type_id;
    if (ref($self)) {
        #MinorImpact::log(8, "ref(\$self)='" . ref($self) . "'");
        $object_type_id = $self->{data}->{object_type_id};
    } else {
        my $DB = MinorImpact::getDB();
        #MinorImpact::log(8, "\$self='$self'");
        if ($self =~/^[0-9]+$/) {
            $object_type_id = $self;
        } else {
            my $singular = $self;
            $singular =~s/s$//;
            $object_type_id = $DB->selectrow_array("select id from object_type where name=? or name=? or plural=?", undef, ($self, $singular, $self));
        }
    }
    #MinorImpact::log(7, "ending");
    return $object_type_id;
}

sub getType {
    #MinorImpact::log(7, "starting");
    my $self = shift;
    my $type_id;

    my $DB = MinorImpact::getDB();

    # Figure out the id of the object type they're looking for.
    if (ref($self)) {
        $type_id = $self->type_id();
    } else {
        $type_id = $self;
        if (!$type_id) {
            if ($MinorImpact::SELF->{conf}{default}{default_object_type}) {
                my $type = $MinorImpact::SELF->{conf}{default}{default_object_type};
                return MinorImpact::Object::typeID($type);
            }
            # If type isn't specified, return the first 'toplevel' object, something that no other object
            # references.
            my $nextlevel = $DB->selectall_arrayref("SELECT DISTINCT object_type_id FROM object_field WHERE type LIKE 'object[%]'");
            if (scalar(@$nextlevel) > 0) {
                my $sql = "SELECT id FROM object_type WHERE id NOT IN (" . join(", ", ('?') x @$nextlevel) . ")";
                #MinorImpact::log(8, "sql=$sql, params=" . join(",", map { $_->[0]; } @$nextlevel));
                $type_id = $DB->selectrow_array($sql, {Slice=>{}}, map {$_->[0]; } @$nextlevel);
            } else {
                $type_id = $DB->selectrow_array("SELECT id FROM object_type", {Slice=>{}});
            }
        } elsif ($type_id !~/^\d+$/) {
            # If someone passes the string name of the type, figure that out for them.
            my $singular = $type_id;
            $singular =~s/e?s$//;
            $type_id = $DB->selectrow_array("SELECT id FROM object_type where name=? or name=? or plural=?", {Slice=>{}}, ($type_id, $singular, $type_id));
        }
    }
    #my $type = $DB->selectrow_hashref("SELECT * FROM object_type where id=?", {Slice=>{}}, ($type_id));
    #my $type = new MinorImpact::Object::Type($type_id);
    #MinorImpact::log(7, "ending");
    return $type_id;
}

# Return an array of all the object types.
sub types {
    my $params = shift || {};
    my $DB = MinorImpact::getDB();

    my $select = "SELECT * FROM object_type";
    my $where = "WHERE id > 0";
    # This was a method of getting types that nothing else refered to, but I implemented that somewhere else,
    # and I might want to put it here, too.
    #if ($params->{toplevel}) {
    #    $where .= " AND toplevel = 1";
    #}
    return $DB->selectall_arrayref("$select $where", {Slice=>{}});
}

sub typeName {
    #MinorImpact::log(7, "starting");
    my $self = shift || return;
    my $params = shift || {};

    my $type_id;
    if (ref($self) eq 'HASH') {
        $params = $self;
        undef($self);
        $type_id = $params->{object_type_id} || $params->{type_id};
    } elsif (ref($self)) {
        $type_id = $params->{object_type_id} || $params->{type_id} || $self->type_id();
    } elsif($self) {
        $type_id = $self;
    }

    my $DB = MinorImpact::getDB();
    my $where = "name=?";
    if ($type_id =~/^[0-9]+$/) {
        $where = "id=?";
    }

    my $sql = "select name, plural from object_type where $where";
    #MinorImpact::log(8, "sql=$sql, ($type_id)");
    my ($type_name, $plural_name) = $DB->selectrow_array($sql, undef, ($type_id));
    if (!$plural_name) {
        $plural_name = $type_name . "s";
    }
    #MinorImpact::log(8, "type_name=$type_name");
    #MinorImpact::log(7, "ending");

    if ($params->{plural}) {
        return $plural_name;
    }
    return $type_name
}

sub _reload {
    my $self = shift || return;
    my $object_id = shift || $self->id();

    #MinorImpact::log(7, "starting(" . $object_id . ")");
         
    $self->{data} = $self->{DB}->selectrow_hashref("select * from object where id=?", undef, ($object_id));
    undef($self->{object_data});

    $self->{object_data} = $self->fields();

    my $data = $self->{DB}->selectall_arrayref("select object_field.name, object_data.id, object_data.value from object_data, object_field where object_field.id=object_data.object_field_id and object_data.object_id=?", {Slice=>{}}, ($self->id()));
    foreach my $row (@$data) {
        if ($self->{object_data}->{$row->{name}}) {

            $self->{object_data}->{$row->{name}}->addValue($row);
        }
    }
    my $text = $self->{DB}->selectall_arrayref("select object_field.name, object_text.id, object_text.value from object_text, object_field where object_field.id=object_text.object_field_id and object_text.object_id=?", {Slice=>{}}, ($self->id()));
    foreach my $row (@$text) {
        if ($self->{object_data}->{$row->{name}}) {
            $self->{object_data}->{$row->{name}}->addValue($row);
        }
    }
    $self->{tags} = $self->{DB}->selectall_arrayref("SELECT * FROM object_tag WHERE object_id=?", {Slice=>{}}, ($object_id)) || [];

    #MinorImpact::log(7, "ending(" . $object_id . ")");
}

sub getTags {
    my $self = shift || return;

    my @tags = ();
    foreach my $data (@{$self->{tags}}) {
        push @tags, $data->{name};
    }
    return @tags;
}

sub tags {
    my $self = shift || return;

    return $self->getTags();
}

sub delete {
    my $self = shift || return;

    $self->log(7, "starting");

    my $data = $self->{DB}->selectall_arrayref("select * from object_field where type like '%object[" . $self->type_id() . "]'", {Slice=>{}});
    foreach my $row (@$data) {
        $self->{DB}->do("DELETE FROM object_data WHERE object_field_id=? and value=?", undef, ($row->{id}, $self->id()));
    }

    my $data = $self->{DB}->selectall_arrayref("select * from object_text where object_id=?", {Slice=>{}}, ($self->id()));
    foreach my $row (@$data) {
        $self->{DB}->do("DELETE FROM object_reference WHERE object_text_id=?", undef, ($row->{id}));
    }

    $self->{DB}->do("DELETE FROM object_data WHERE object_id=?", undef, ($self->id()));
    $self->{DB}->do("DELETE FROM object_text WHERE object_id=?", undef, ($self->id()));
    $self->{DB}->do("DELETE FROM object_reference WHERE object_id=?", undef, ($self->id()));
    $self->{DB}->do("DELETE FROM object_tag WHERE object_id=?", undef, ($self->id()));
    $self->{DB}->do("DELETE FROM object WHERE id=?", undef, ($self->id()));

    $self->log(7, "ending");
}

sub _search {
    my $params = shift || {};

    #MinorImpact::log(7, "starting");
    my $DB = $MinorImpact::SELF->{DB};

    $params->{object_type_id} = $params->{object_type} if ($params->{object_type} && !$params->{object_type_id});
    my $select = "SELECT DISTINCT(object.id) FROM object JOIN object_type ON (object.object_type_id=object_type.id) LEFT JOIN object_tag ON (object.id=object_tag.object_id) LEFT JOIN object_data ON (object.id=object_data.object_id) LEFT JOIN object_text ON (object.id=object_text.object_id)";
    my $where = "WHERE object.id > 0 ";
    my @fields;

    $select .= $params->{select} if ($params->{select});
    $where .= " AND " . $params->{where} if ($params->{where});

    foreach my $param (keys %$params) {
        next if ($param =~/^(id_only|sort|limit|page)$/);
        #MinorImpact::log(8, "search key='$param'");
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
                unshift(@fields, $tag);
            }
            $where .= " AND object_tag.object_id IN ($tag_where)" if ($tag_where);
        } elsif ($param eq "description") {
            $where .= " AND object.description like ?";
            push(@fields, "\%$params->{description}\%");
        } elsif ($param eq "text" || $param eq "search") {
            my $text = $params->{text} || $params->{search};
            if ($text) {
                $where .= " AND (object.name LIKE ? OR object.description LIKE ? OR object_data.value LIKE ? OR object_text.value LIKE ?)";
                push(@fields, "\%$text\%");
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
                $where .= " AND (object_data.object_field_id=? AND object_data.value=?)";
                push(@fields, $object_field_id);
                push(@fields, $params->{$param});
            }
        }
    }

    my $sql = "$select $where";
    MinorImpact::log(3, "sql='$sql', \@fields='" . join(',', @fields) . "'");

    my $objects = $DB->selectall_arrayref($sql, {Slice=>{}}, @fields);

    #MinorImpact::log(7, "ending");
    return map { $_->{id}; } @$objects;
}

sub log {
    my $self = shift || return;
    my $level = shift || return;
    my $message = shift || return;

    MinorImpact::log($level, $message);
    return;
}

sub search {
    my $params = shift || {};

    #MinorImpact::log(7, "starting");

    my $local_params = cloneHash($params);
    # TODO: Right now you can only search for things that belong to the currently logged in
    #   user.  That's not usefull in the long run.
    if (!$local_params->{user_id}) {
        my $user = $MinorImpact::SELF->getUser();
        $local_params->{user_id} = $user->id() || redirect("index.cgi");
    }

    if ($local_params->{text}) {
        my $text = $local_params->{text};
        while (my ($match, $tag) = $text =~/ ?(tag:(\w+)) ?/ig) {
            $text =~s/$match/ /;
            $local_params->{tag} .= "$tag,";
        }
        $text = trim($text);
        $local_params->{text} = $text;
        $local_params->{tag} =~s/,$//;
    }

    my @ids = _search($local_params);
    # TODO: There's no sorting or type tree or pagination allowed if someone just wants a raw list
    #   of IDs.  Does it make sense to change things?  Is it more likely they're going to do this
    #   on their own if they're that type of consumer?  Is it logical to say "you can't sort them
    #   unless you also want the overhead of  creating the full object;  you can't have your cake
    #   and eat it too."
    return @ids if ($params->{id_only});

    my @objects;
    foreach my $id (@ids) {
        #MinorImpact::log(8, "\$id=" . $id);
        my $object = new MinorImpact::Object($id);
        push(@objects, $object);
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
        push(@{$objects->{$object->type_id()}}, $object);
    }
    #MinorImpact::log(7, "ending");
    return $objects;
}

sub getChildTypes {
    my $self = shift || return;
    my $params = shift || {};

    #MinorImpact::log(7, "starting");
    $params->{object_type_id} = $params->{type_id} if ($params->{type_id} && !$params->{object_type_id});

    my @childTypes;
    my $data = $self->{DB}->selectall_arrayref("select DISTINCT object_type_id from object_field where type like '%object[" . $self->type_id() . "]'", {Slice=>{}});
    foreach my $row (@$data) {
        next if ($params->{object_type_id} && ($params->{object_type_id} != $row->{object_type_id}));
        if ($params->{id_only}) {
            push(@childTypes, $row->{object_type_id});
        } else {
            push(@childTypes, $row->{object_type_id});
            #push (@childTypes, new MinorImpact::Object::Type($row->{object_type_id}));
        }
    }
    #MinorImpact::log(7, "ending");
    return @childTypes;
}

sub getChildren {
    my $self = shift || return;
    my $params = shift || {};

    #MinorImpact::log(7, "starting(" . $self->id() . ")");
    my $local_params = cloneHash($params);
    $local_params->{object_type_id} = $local_params->{type_id} if ($local_params->{type_id} && !$local_params->{object_type_id});

    my @children;
    my $data = $self->{DB}->selectall_arrayref("select * from object_field where type like '%object[" . $self->type_id() . "]'", {Slice=>{}});
    foreach my $row (@$data) {
        next if ($local_params->{object_type_id} && ($local_params->{object_type_id} != $row->{object_type_id}));

        my $sql = "SELECT object_data.object_id, object_field.object_type_id FROM object_data, object_field WHERE object_field.id=object_data.object_field_id and object_data.object_field_id=? and object_data.value=?";
        MinorImpact::log(3, "$sql, \@fields='" . $row->{id} . "', '" . $self->id() . "'");
        foreach my $r2 (@{$self->{DB}->selectall_arrayref($sql, {Slice=>{}}, ($row->{id}, $self->id()))}) {
            if ($local_params->{id_only}) {
                push(@children, $r2->{object_id});
            } else {
                #MinorImpact::log(8, "creating new object '" . $r2->{object_id} . "'");
                push(@children, new MinorImpact::Object($r2->{object_id}));
            }
        }
        #MinorImpact::log(8, "found " . scalar(@results) . " so far");
    }

    if ($local_params->{sort}) {
        if ($local_params->{id_only}) {
            @children = sort @children;
        } else {
            @children = sort {$a->cmp($b); } @children;
        }
    }
    #MinorImpact::log(8, "returning " . scalar(@children));
    return @children;
}

# Renders an object to a string in a specified format.
#
# Parameters
#   format
#     'column': Standard full page representation.
#     'json': JSON data object.
#     'text': straight text, no markup; similar to $object->name().
#     'row': a horizontal represenation, in cells.
sub toString {
    my $self = shift || return;
    my $params = shift || {};
    #$self->log(7, "starting");

    my $script_name = $params->{script_name} || MinorImpact::scriptName() || 'index.cgi';

    my $MINORIMPACT = new MinorImpact();
    my $TT = $MINORIMPACT->getTT();

    my $string = '';
    if ($params->{column}) { $params->{format} = "column";
    } elsif ($params->{row}) { $params->{format} = "row";
    } elsif ($params->{json}) {$params->{format} = "json";
    } elsif ($params->{text}) {$params->{format} = "text";
    } 
    if ($params->{format} eq 'column') {
        #$tt->process('object_column', { object=> $self}, \$string) || die $tt->error();
        $string .= "<table class=view>\n";
        foreach my $name (keys %{$self->{object_data}}) {
            my $field = $self->{object_data}{$name};
            #MinorImpact::log(7, "processing $name");
            my $type = $field->type();
            next if ($field->get('hidden'));
            my $value;
            if ($type =~/object\[(\d+)\]$/) {
                foreach my $v ($field->value()) {
                    if ($v && $v =~/^\d+/) {
                        my $o = new MinorImpact::Object($v);
                        $value .= $o->toString() if ($o);
                    }
                }
            } elsif ($type =~/text$/) {
                foreach my $val ($field->toString()) {
                    my $id = $field->id();
                    my $references = $self->getReferences($id);
                    foreach my $ref (@$references) {
                        my $test_data = $ref->{data};
                        $test_data =~s/\W/ /gm;
                        $test_data = join("\\W+?", split(/[\s\n]+/, $test_data));
                        if ($val =~/($test_data)/mgi) {
                            my $match = $1;
                            my $url = "$script_name?id=" . $ref->{object_id};
                            $val =~s/$match/<a href='$url'>$ref->{data}<\/a>/;
                        }
                    }
                    $value .= "<div onmouseup='getSelectedText($id);'>$val</div>\n";
                }
            } else {
                $value = $field->toString();
            }
            my $row;
            $TT->process('field_column', {name=>$field->displayName(), value=>$value}, \$row) || die $TT->error();
            $string .= $row;
        }
        $string .= "<!-- CUSTOM -->\n";
        $string .= "</table>\n";

        # Don't display children by default.  Will look into add the tabbed
        # system in later revision.
        #my $children = $self->getChildren();
        #my @child_types = $self->getChildTypes();
        #foreach my $child_type (sort { $a->cmp(%b); }  @child_types) {
        #my $child_type_id = $child_type->id();
        #$string .= "<h2>" . $child_type->name({plural=>1}) . "</h2>\n";
        #$string .= "<table>\n";
        #foreach my $o (sort { $a->cmp($b); } @{$children->{$child_type_id}}) {
        #$string .= "<tr><td>" . $o->toString() . "</td></tr>\n";
        #}
        #$string .= "</table>\n";
        #}

        my $references = $self->getReferences();
        if (scalar(@$references)) {
            $string .= "<h2>References</h2>\n";
            $string .= "<table>\n";
            foreach my $ref (@$references) {
                my $object = new MinorImpact::Object($ref->{object_id});
                $string .= "<tr><td>" . $object->toString(). "</td><td></td></tr>\n";
                $string .= "<tr><td colspan=2>\"" . $ref->{data} . "\"</td></tr>\n";
            }
            $string .= "</table>\n";
        }

        foreach my $tag ($self->getTags()) {
            $string .= "<a class=tag href='search.cgi?search=tag:$tag'>#$tag</a>";
        }
    } elsif ($params->{format} eq 'row') {
        foreach my $key (keys %{$self->{data}}) {
            $string .= "<td>$self->{data}{$key}</td>\n";
        }
    } elsif ($params->{format} eq 'json') {
        #$tt->process('object', { object=> $self}, \$string) || die $tt->error();
        $string = to_json($self->toData());
    } elsif ($params->{format} eq 'text') {
        $string = $self->name();
    } elsif ($params->{format} eq 'list') {
        $string = "<tr><td>" . $self->toString() . "</td></tr>";
    } else {
        my $template = $params->{template} || 'object';
        $TT->process('object', { object => $self }, \$string) || die $TT->error();
    }
    #$self->log(7, "ending");
    return $string;
}

sub toData {
    my $self = shift || return;

        my $data = {};
        $data->{id} = $self->id();
        $data->{name} = $self->name();
        $data->{description} = $self->get('description');
        $data->{type_id} = $self->type_id();
        my $fields = $self->fields();
        foreach my $name (keys %$fields) {
            my $field = $fields->{$name};
            my @values = $field->value();
            if ($field->isArray()) {
                $data->{$name} = $values[0];
            } else {
                $data->{$name} = \@values;
            }
        }
        #$data->{children} = $self->getChildren({id_only=>1});
        #@{$data->{tags}} = ($self->getTags());
    return $data;
}


sub getReferences {
    my $self = shift || return;
    my $object_text_id = shift;

    my $DB = MinorImpact::getDB();
    if ($object_text_id) {
        # Only return references to a particular 
        return $DB->selectall_arrayref("select object_id, data, object_text_id from object_reference where object_text_id=?", {Slice=>{}}, ($object_text_id));
    }
    # Return all references for this object.
    return $DB->selectall_arrayref("select object.id as object_id, object_reference.data from object_reference, object_text, object where object_reference.object_text_id=object_text.id and object_text.object_id=object.id and object_reference.object_id=?", {Slice=>{}}, ($self->id()));
}

sub form {
    my $self = shift || {};
    my $params = shift || {};
    #MinorImpact::log(7, "starting");

    if (ref($self) eq "HASH") {
        $params = $self;
        undef($self);
    } elsif (!ref($self)) {
        undef($self);
    }

    my $user_id = $MinorImpact::SELF->getUser()->id();
    my $CGI = MinorImpact::getCGI();

    my $local_params = cloneHash($params);
    my $type;
    if ($self) {
        $local_params->{object_type_id} = $self->type_id();
    } elsif (!($local_params->{object_type_id} || $local_params->{type_id})) {
        die "Can't create a form with no object_type_id.\n";
    }
    my $object_type_id = $local_params->{object_type_id} || $local_params->{type_id};


    my $form = <<FORM;
    <form method=POST>
        <input type=hidden name=id value="${\ ($self?$self->id():''); }">
        <input type=hidden name=a value="${\ ($self?'edit':'add'); }">
        <input type=hidden name=type_id value="$object_type_id">
        <table class=edit>
FORM
    unless ($params->{no_name}) {
     $form .= <<FORM;
        <tr>   
                <td class=fieldname>Name</td>
                <td><input type=text name=name value="${\ ($CGI->param('name') || ($self && $self->name())); }"></td>
            </tr>
FORM
     }
    # Suck in any default values passed in the parameters.
    foreach my $field (keys %{$params->{default_values}}) {
        $CGI->param($field,$params->{default_values}->{$field});
    }

    # Add fields for the last things they were looking at.
    unless ($self) {
        my $view_history = MinorImpact::CGI::viewHistory();
        foreach my $field (keys %$view_history) {
            my $value = $view_history->{$field};
            #MinorImpact::log(8, "\$view_history->{$field} = '$value'");
            $CGI->param($field, $value) unless ($CGI->param($field));
        }
    }

    #my $cookie_object_id = $CGI->cookie('object_id');
    #if ($cookie_object_id) {
    #    my $cookie_object = new MinorImpact::Object($cookie_object_id);
    #    if ($cookie_object) {
    #        my $field = $cookie_object->typeName()."_id";
    #        $CGI->param($field, $cookie_object->id()) unless ($CGI->param($field));
    #    }
    #}

    my $fields;
    if ($self) {
        $fields = $self->{object_data};
    } else {
        $fields = MinorImpact::Object::fields($object_type_id);
    }
    my $script;
    foreach my $name (keys %$fields) {
        my $field = $fields->{$name};
        my $field_type = $field->type();
        #MinorImpact::log(8, "\$field->{name}='$field->{name}'");
        next if ($field->get('hidden') || $field->get('readonly'));
        my @params = $CGI->param($name);
        my @values;
        if (scalar(@params) > 0) {
            foreach my $field (@params) {
                push (@values, $field) unless ($field eq '');
            }
        } else {
            @values = $field->value();
        }

        my $local_params = cloneHash($params);
        $local_params->{field_type} = $field_type;
        $local_params->{required} = $field->get('required');
        $local_params->{name} = $name;
        $local_params->{value} = \@values;
        $form .= $field->formRow($local_params);
    }
    $form .= <<FORM;
            <!-- CUSTOM -->
            <tr>   
                <td class=fieldname>Tags</td>
                <td><input type=text name=tags value='${\ ($CGI->param('tags') || ($self && join(' ', $self->getTags()))); }'></td>
            </tr>
            <tr>
                <td></td>
                <td><input type=submit name=submit></td>
            </tr>
        </table>
    </form>
FORM

    $form = "<script>$script</script>$form(" . ref($self) . ")";
    #MinorImpact::log(7, "ending");
    return $form;
}

# Used to compare one object to another for purposes of sorting.
# Example:
#   @sorted_object_list = sort { $a->cmp($b); } @object_list;
# Without an argument return the $value of the sortby field.
# Example:
#   @sorted_object_list = sort { $a->cmp() cmp $b->cmp(); } @object_list;
sub cmp {
    my $self = shift || return;
    my $b = shift;

    my $sortby = 'name';
    foreach my $field_name (keys %{$self->{object_data}}) {
        my $field = $self->{object_data}{$field_name};
        $sortby = $field->name() if ($field->get('sortby'));
    }
    if ($b) {
        return ($self->get($sortby) cmp $b->cmp());
    } else {
        return $self->get($sortby);
    }
}

# Returns the object_field id from the type/field name.
# Convenience method so searching/filtering can be done by name rather than id.
sub fieldID {
    my $object_type = shift || return;
    my $field_name = shift || return;

    my $object_type_id = MinorImpact::Object::type_id($object_type);
    #MinorImpact::log(8, "object_type_id='$object_type_id',field_name='$field_name'");
    my $DB = MinorImpact::getDB();
    #MinorImpact::log(8, "SELECT id FROM object_field WHERE object_type_id='$object_type_id' AND name='$field_name'");
    my $data = $DB->selectall_arrayref("SELECT id FROM object_field WHERE object_type_id=? AND name=?", {Slice=>{}}, ($object_type_id, $field_name));
    if (scalar(@{$data}) > 0) {
        return @{$data}[0]->{id};
    }
}

1;
