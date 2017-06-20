package MinorImpact::Object;

use Data::Dumper;
use JSON;

use MinorImpact;
use MinorImpact::Util;
use MinorImpact::Object::Type;
use MinorImpact::Object::Field;
use MinorImpact::Text::Markdown 'markdown';

sub new {
    my $package = shift || return;
    my $id = shift || return;

    MinorImpact::log(7, "starting");

    my $DB = MinorImpact::getDB();
    my $object;

    eval {
        my $type_name;
        if (ref($id) eq "HASH") {
            my $data = $DB->selectrow_hashref("SELECT name FROM object_type ot WHERE ot.id=?", undef, ($id->{type_id})) || die $MinorImpact::SELF->{DB}->errstr;
            $type_name = $data->{name}; 
        } else {
            my $data = $DB->selectrow_hashref("SELECT ot.name FROM object o, object_type ot WHERE o.object_type_id=ot.id AND o.id=?", undef, ($id)) || die $MinorImpact::SELF->{DB}->errstr;
            $type_name = $data->{name};
        }
        MinorImpact::log(7, "trying to create new '$type_name' with id='$id'");
        $object = $type_name->new($id) if ($type_name);
    };
    MinorImpact::log(1, $@) if ($@);
    if ($@ =~/^error:/) {
        my $error = $@;
        $error =~s/ at \/.*$//;
        $error =~s/^error://;
        die $error;
    }
    unless ($object) {
        $object = MinorImpact::Object::_new($package, $id);
    }
    MinorImpact::log(7, "ending");
    return $object;
}

sub _new {
    my $package = shift;
    my $params = shift;

    my $self = {};
    bless($self, $package);

    MinorImpact::log(7, "starting");
    MinorImpact::log(8, "package='$package'");
    my $type_name = lc($package);
    if ($type_name && !$params->{type_id}) {
        $params->{type_id} = type_id($type_name);
    }
    $self->{DB} = MinorImpact::getDB() || die;
    $self->{CGI} = MinorImpact::getCGI() || die;

    my $object_id;
    if (ref($params) eq 'HASH') {
        MinorImpact::log(8, "ref(\$params)='" . ref($params) . "'");
        my $user_id = $params->{'user_id'} || $MinorImpact::SELF->getUser()->id();
        die "error:invalid name" unless ($params->{name});
        die "error:invalid user id" unless ($user_id);
        die "error:invalid type id" unless ($params->{type_id});
        my $data = $self->{DB}->selectall_arrayref("select * from object_field where object_type_id=?", {Slice=>{}}, ($params->{type_id}));
        foreach my $row (@$data) {
            my $field_name = $row->{name};
            MinorImpact::log(8, "field_name='$field_name'");
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
            MinorImpact::log(8, "field_name/field_type='$field_name/$field_type'");
            if (defined $params->{$field_name}) {
                MinorImpact::log(8, "\$params->{$field_name} defined, = '" . $params->{$field_name} . "'");
                if ($field_type eq 'boolean') {
                    $self->{DB}->do("insert into object_data(object_id, object_field_id, value) values (?, ?, ?)", undef, ($object_id, $row->{id}, 1)) || die $self->{DB}->errstr;
                } else {
                    foreach my $value (split(/\0/, $params->{$field_name})) {
                        MinorImpact::log(8, "$field_name='$value'");
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

    MinorImpact::log(7, "ending");
    return $self;
}

sub id { my $self = shift || return; return $self->{data}->{id}; }
sub name { my $self = shift || return; return $self->get('name'); }
sub user_id { my $self = shift || return; return $self->get('user_id'); }   

sub selectList {
    my $self = shift || return;
    my $params = shift || {};

    MinorImpact::log(7, "starting");
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

    my $select = "<select id='$local_params->{fieldname}' name='$local_params->{fieldname}'>\n";
    $select .= "<option></option>\n" unless ($local_params->{required});
    my @objects = search($local_params);
    foreach my $object (@objects) {
        $select .= "<option value='" . $object->id() . "'";
        if ($local_params->{selected} && $local_params->{selected} == $object->id()) {
            $select .= " selected";
        }
        $select .= ">" . $object->name() . "</option>\n";
    }
    $select .= "</select>\n";
    MinorImpact::log(7, "ending");
    return $select;
}

sub get {
    my $self = shift || return;
    my $name = shift || return;
    my $params = shift || {};

    if (defined($self->{data}->{$name})) {
       return $self->{data}->{$name};
    }
    if (defined($self->{object_data}->{$name})) {
        my $value = $self->{object_data}->{$name}->value();
        if ($params->{markdown}) {
            return markdown($value);
        } else {
            return $value;
        }
    }
}   

sub validateFields {
    my $fields = shift;
    my $params = shift;

    die "uh..." unless ($fields && $params);

    foreach my $field_name (keys %$fields) {  
        my $field = $fields->{$field_name};
        $field->validate($params->{$field_name});
        my $field_type = $fields->{$field_name}->type();
        if (defined($params->{$field_name}) && !$params->{$field_name} && $row->{required}) {
            die "$field_name cannot be blank";
        }   
        if ($field_type eq 'boolean') {
            $params->{$field_name} = ($params->{$field_name}?1:0);
        }   
    }
}

sub update {
    my $self = shift || return;
    my $params = shift || return;

    $self->log(7, "starting");
    $self->{DB}->do("UPDATE object SET name=? WHERE id=?", undef, ($params->{'name'}, $self->id())) if ($params->{name});
    $self->{DB}->do("UPDATE object SET description=? WHERE id=?", undef, ($params->{'description'}, $self->id())) if (defined($params->{description}));
    $self->log(1, $self->{DB}->errstr) if ($self->{DB}->errstr);

    my $fields = $self->fields();
    validateFields($fields, $params);
    foreach my $field_name (keys %$fields) {
        my $field = $fields->{$field_name};
        my $field_type = $field->type();
        if (defined $params->{$field_name}) {
            $self->{DB}->do("delete from object_data where object_id=? and object_field_id=?", undef, ($self->id(), $field->get('object_field_id'))) || die $self->{DB}->errstr;
            $self->{DB}->do("delete from object_text where object_id=? and object_field_id=?", undef, ($self->id(), $field->get('object_field_id'))) || die $self->{DB}->errstr;
            foreach my $value (split(/\0/, $params->{$field_name})) {
                if ($field_type =~/text$/ || $field_type eq 'url') {
                    $self->{DB}->do("insert into object_text(object_id, object_field_id, value, create_date) values (?, ?, ?, NOW())", undef, ($self->id(), $field->get('object_field_id'), $value)) || die $self->{DB}->errstr;
                } else {
                    MinorImpact::log(8, "insert into object_data(object_id, object_field_id, value, create_date) values (?, ?, ?, NOW()) (" . $self->id() . ", " . $field->get('object_field_id') . ", $value)");
                    $self->{DB}->do("insert into object_data(object_id, object_field_id, value, create_date) values (?, ?, ?, NOW())", undef, ($self->id(), $field->get('object_field_id'), $value)) || die $self->{DB}->errstr;
                }
            }
        }
    }

    foreach $param (keys %$params) {
        if ($param =~/^tags$/) {
            $self->{DB}->do("DELETE FROM object_tag WHERE object_id=?", undef, ($self->id()));
            $self->log(1, $self->{DB}->errstr) if ($self->{DB}->errstr);
            foreach my $tag (split(/\0/, $params->{$param})) {
                foreach my $tag (parseTags($tag)) {
                    next unless ($tag);
                    $self->{DB}->do("INSERT INTO object_tag (name, object_id) VALUES (?,?)", undef, ($tag, $self->id())) || die("Can't add object tag:" . $self->{DB}->errstr);
                }
            }
        }
    }
    $self->_reload();
    $self->log(7, "ending");
    return;
}

sub fields {
    my $self = shift;

    my $fields;
    if (ref($self)) {
        $fields = $self->{object_data};
    } else {
        my $DB = MinorImpact::getDB();
        my $data = $DB->selectall_arrayref("select * from object_field where object_type_id=?", {Slice=>{}}, ($self));
        foreach my $row (@$data) {
           $fields->{$row->{name}} = new MinorImpact::Object::Field($row->{type}, $row);
        }
    }
    return $fields;
}

sub type_id {
    my $self = shift || return;

    MinorImpact::log(7, "starting");
    my $object_type_id;
    if (ref($self)) {
        MinorImpact::log(8, "ref(\$self)='" . ref($self) . "'");
        $object_type_id = $self->{data}->{object_type_id};
    } else {
        my $DB = MinorImpact::getDB();
        MinorImpact::log(8, "\$self='$self'");
        if ($self =~/^[0-9]+$/) {
            $object_type_id = $self;
        } else {
            $object_type_id = $DB->selectrow_array("select id from object_type where name=?", undef, ($self));
        }
    }
    MinorImpact::log(7, "ending");
    return $object_type_id;
}

sub getType {
    MinorImpact::log(7, "starting");
    my $self = shift;
    my $type_id;

    my $DB = MinorImpact::getDB();

    # Figure out the id of the object type they're looking for.
    if (ref($self)) {
        $type_id = $self->type_id();
    } else {
        $type_id = $self;
        if (!$type_id) {
            #$type_id = $DB->selectrow_array("SELECT id FROM object_type where toplevel = 1", {Slice=>{}});
            # If type isn't specified, return the first 'toplevel' object, something that no other object
            # references.
            my $nextlevel = $DB->selectall_arrayref("SELECT DISTINCT object_type_id FROM object_field WHERE type LIKE 'object[%]'");
            my $sql = "SELECT id FROM object_type WHERE id NOT IN (" . join(", ", ('?') x @$nextlevel) . ")";
            MinorImpact::log(8, "sql=$sql, params=" . join(",", map { $_->[0]; } @$nextlevel));
            $type_id = $DB->selectrow_array($sql, {Slice=>{}}, map {$_->[0]; } @$nextlevel);
        } elsif ($type_id !~/^\d+$/) {
            # If someone passes the string name of the type, figure that out for them.
            my $singular = $type_id;
            $singular =~s/e?s$//;
            $type_id = $DB->selectrow_array("SELECT id FROM object_type where name=? or name=? or plural=?", {Slice=>{}}, ($type_id, $singular, $type_id));
        }
    }
    #my $type = $DB->selectrow_hashref("SELECT * FROM object_type where id=?", {Slice=>{}}, ($type_id));
    my $type = new MinorImpact::Object::Type($type_id);
    MinorImpact::log(7, "ending");
    return $type;
}

# Return an array of all the object types.
sub types {
    my $params = shift || {};
    my $DB = MinorImpact::getDB();

    my $select = "SELECT * FROM object_type";
    my $where = "WHERE id > 0";
    if ($params->{toplevel}) {
        $where .= " AND toplevel = 1";
    }
    return $DB->selectall_arrayref("$select $where", {Slice=>{}});
}

sub typeName {
    MinorImpact::log(7, "starting");
    my $self = shift;
    my $params = shift || {};

    my $type_id;
    if (ref($self)) {
        $type_id = $self->type_id();
    } elsif($self) {
        $type_id = $self;
    }

    my $DB = MinorImpact::getDB();
    my $where = "name=?";
    if ($type_id =~/^[0-9]+$/) {
        $where = "id=?";
    } else {
        # This is stupid, I just don't want to have support a sql statement where I have to
        # pass arbitrary parameters.
        $type_id = 1;
        $where = "`default` = ?";
    }

    my $sql = "select name, plural from object_type where $where";
    MinorImpact::log(8, "sql=$sql, ($type_id)");
    my ($type_name, $plural_name) = $DB->selectrow_array($sql, undef, ($type_id));
    MinorImpact::log(8, "type_name=$type_name");
    MinorImpact::log(7, "ending");
    return ($params->{plural}?($plural_name?$plural_name:$type_name . "s"):$type_name);
}

sub _reload {
    my $self = shift || return;
    my $object_id = shift || $self->id();

    $self->log(7, "starting");
    $self->{data} = $self->{DB}->selectrow_hashref("select * from object where id=?", undef, ($object_id));
    undef($self->{object_data});
    #my $data = $self->{DB}->selectall_arrayref("select object_data.id AS data_id, object_data.value, object_field.* from object_data, object_type, object, object_field where object_field.id=object_data.object_field_id and object_data.object_id=object.id and object.object_type_id=object_type.id and object.id=?", {Slice=>{}}, ($object_id));
    my $fields = $self->{DB}->selectall_arrayref("select object_field.* from object_field where object_field.object_type_id=?", {Slice=>{}}, ($self->type_id()));

    foreach my $row (@$fields) {
        $self->{object_data}->{$row->{name}} = new MinorImpact::Object::Field($row->{type}, $row);
    }

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

    #$self->{object_type} = $self->{DB}->selectrow_hashref("select * from object_type where id=?", undef, ($self->type_id()));
    #$self->{object_field} = $self->{DB}->selectall_arrayref("select * from object_field where object_type_id=?", {Slice=>{}}, ($self->type_id()));

    #foreach my $field (@{$self->{object_field}}) {
    #   my $name = $field->{name};
    #   my $displayname = ucfirst($name);
    #   $displayname =~s/_id$//;
    #   $displayname =~s/_/ /g;
    #   $field->{displayname} = $displayname;
    #}

    $self->log(7, "ending");
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

    MinorImpact::log(7, "starting");
    my $DB = $MinorImpact::SELF->{DB};

    $params->{object_type_id} = $params->{object_type} if ($params->{object_type} && !$params->{object_type_id});
    my $select = "SELECT DISTINCT(object.id) FROM object JOIN object_type ON (object.object_type_id=object_type.id) LEFT JOIN object_tag ON (object.id=object_tag.object_id) LEFT JOIN object_data ON (object.id=object_data.object_id) LEFT JOIN object_text ON (object.id=object_text.object_id)";
    my $where = "WHERE object.id > 0 ";
    my @fields;

    $select .= $params->{select} if ($params->{select});
    $where .= $params->{where} if ($params->{where});

    foreach my $param (keys %$params) {
        next if ($param =~/^(id_only|sort|limit|page)$/);
        MinorImpact::log(8, "search key='$param'");
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
            $where .= " AND object_tag.name=?";
            push(@fields, $params->{tag});
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
            MinorImpact::log(8, "trying to get a field id for '$param'");
            my $object_field_id = MinorImpact::Object::fieldID($params->{object_type_id}, $param);
            if ($object_field_id) {
                $where .= " AND (object_data.object_field_id=? AND object_data.value=?)";
                push(@fields, $object_field_id);
                push(@fields, $params->{$param});
            }
        }
    }

    my $sql = "$select $where";
    MinorImpact::log(8, "sql='$sql', \@fields='" . join(',', @fields) . "'");

    my $objects = $DB->selectall_arrayref($sql, {Slice=>{}}, @fields);

    MinorImpact::log(7, "ending");
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

    MinorImpact::log(7, "starting");

    my $local_params = cloneHash($params);
    $local_params->{user_id} = $MinorImpact::SELF->getUser()->id() || redirect("index.cgi");
    my @ids = _search($local_params);
    return @ids if ($params->{id_only});
    my @objects;
    foreach my $id (@ids) {
        MinorImpact::log(8, "\$id=" . $id);
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
        MinorImpact::log(7, "ending");
        return @objects;
    }

    # Return a hash of arrays organized by type.
    my $objects;
    foreach my $object (@objects) {
        push(@{$objects->{$object->type_id()}}, $object);
    }
    MinorImpact::log(7, "ending");
    return $objects;
}

sub getChildTypes {
    my $self = shift || return;
    my $params = shift || {};

    MinorImpact::log(7, "starting");
    $params->{object_type_id} = $params->{type_id} if ($params->{type_id} && !$params->{object_type_id});

    my @childTypes;
    my $data = $self->{DB}->selectall_arrayref("select DISTINCT object_type_id from object_field where type like '%object[" . $self->type_id() . "]'", {Slice=>{}});
    foreach my $row (@$data) {
        next if ($params->{object_type_id} && ($params->{object_type_id} != $row->{object_type_id}));
        if ($params->{id_only}) {
            push(@childTypes, $row->{object_type_id});
        } else {
            push (@childTypes, new MinorImpact::Object::Type($row->{object_type_id}));
        }
    }
    MinorImpact::log(7, "ending");
    return @childTypes;
}
sub getChildren {
    my $self = shift || return;
    my $params = shift || {};

    MinorImpact::log(7, "starting");
    my $local_params = cloneHash($params);
    $local_params->{object_type_id} = $local_params->{type_id} if ($local_params->{type_id} && !$local_params->{object_type_id});

    my @children;
    my $data = $self->{DB}->selectall_arrayref("select * from object_field where type like '%object[" . $self->type_id() . "]'", {Slice=>{}});
    foreach my $row (@$data) {
        next if ($local_params->{object_type_id} && ($local_params->{object_type_id} != $row->{object_type_id}));

        foreach my $r2 (@{$self->{DB}->selectall_arrayref("SELECT object_data.object_id, object_field.object_type_id
            FROM object_data, object_field
            WHERE object_field.id=object_data.object_field_id and object_data.object_field_id=? and object_data.value=?", {Slice=>{}}, ($row->{id}, $self->id()))}) {
            if ($local_params->{id_only}) {
                #push(@{$children->{$r2->{object_type_id}}}, $r2->{object_id});
                push(@children, $r2->{object_id});
            } else {
                #push(@{$children->{$r2->{object_type_id}}}, new MinorImpact::Object($r2->{object_id}));
                push(@children, new MinorImpact::Object($r2->{object_id}));
            }
        }
    }

    if ($local_params->{sort}) {
        if ($local_params->{id_only}) {
            @children = sort @children;
        } else {
            @children = sort {$a->cmp($b); } @children;
        }
    }
    MinorImpact::log(7, "ending");
    return @children;
}

sub toString {
    my $self = shift || return;
    my $params = shift || {};
    $self->log(7, "starting");

    my $script_name = $params->{script_name} || MinorImpact::scriptName() || 'object.cgi';

    my $MINORIMPACT = new MinorImpact();
    my $tt = $MINORIMPACT->templateToolkit();

    my $string = '';
    if ($params->{column}) {
        #$tt->process('object_column', { object=> $self}, \$string) || die $tt->error();
        $string .= "<table class=view>\n";
        my $fields = $self->fields();
        foreach my $name (keys %{$fields}) {
            my $field = $fields->{$name};
            MinorImpact::log(7, "processing $name");
            my $type = $field->type();
            next if ($field->get('hidden'));
                $string .= "<tr><td class=fieldname>" . $field->displayName() . "</td><td>";
                if ($type =~/object\[(\d+)\]$/) {
                    foreach my $value ($field->value()) {
                        if ($value && $value =~/^\d+/) {
                            my $o = new MinorImpact::Object($value);
                            $string .= $o->toString();
                        }
                    }
                } elsif ($type =~/text$/) {
                    foreach my $value ($field->value()) {
                        my $id = $field->id();
                        my $references = $self->getReferences($id);
                        foreach my $ref (@$references) {
                            $value =~s/ +/ /g;
                            if ($value =~/$ref->{data}/) {
                                my $url = "$script_name.cgi?id=" . $ref->{object_id};
                                $value =~s/$ref->{data}/<a href='$url'>$ref->{data}<\/a>/;
                            }
                        }
                        $string .= "<p onmouseup='getSelectedText($id);'>$value</p>\n";
                    }
                } else {
                    $string .= $field->toString();
                }
                $string .= "</td></tr>\n";
            }
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
            $string .= "<a class=tag href=tags.cgi?search_tag=$tag>#$tag</a>";
        }
    } elsif ($params->{row}) {
        foreach my $key (keys %{$self->{data}}) {
            $string .= "<td>$self->{data}{$key}</td>\n";
        }
    } elsif ($params->{json}) {
        $tt->process('object', { object=> $self}, \$string) || die $tt->error();
        my $json = {};
        my $fields = $self->fields();
        $json->{name} = $self->{data}->{name};
        $json->{description} = $self->{data}->{description};
        $json->{type_id} = $self->type_id();
        foreach my $f (@$fields) {
            my $name = $f->{name};
            if (defined($self->{object_data}->{$name})) {
                if ($f->{type} =~/^\@/) {
                    $json->{$name} = $self->{object_data}->{$name};
                } else {
                    $json->{$name} = @{$self->{object_data}->{$name}}[0];
                }
            }
        }
        $json->{children} = $self->getChildren({id_only=>1});
        @{$json->{tags}} = ($self->getTags());
        $string = to_json($json);
    } else {
        my $template = $params->{template} || 'object';
        $tt->process('object', { object=> $self}, \$string) || die $tt->error();
        #$string .= "<a href='$script_name?id=" . $self->id() . "'>" . $self->name() . "</a>";
    }
    $self->log(7, "ending");
    return $string;
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
    MinorImpact::log(7, "starting");

    if (ref($self) eq "HASH") {
        $params = $self;
        undef($self);
    } else {
    }

    my $object_id;
    my $object_type_id;
    my $user_id;

    $object_id = $self->id() if ($self);
    $object_type_id = $self?$self->type_id():$params->{object_type_id};
    $user_id = $MinorImpact::SELF->getUser()->id();
    MinorImpact::log(8, "\$user_id='$user_id'");
    return unless ($object_type_id);
    
    my $CGI = MinorImpact::getCGI();
    
    my $form = <<FORM;
    <form method=POST>
        <input type=hidden name=id value="${\ ($object_id?$object_id:''); }">
        <input type=hidden name=a value="${\ ($object_id?'edit':'add'); }">
        <input type=hidden name=type_id value="$object_type_id">
        <table class=edit>
            <tr>   
                <td class=fieldname>Name</td>
                <td><input type=text name=name value="${\ ($CGI->param('name') || ($self && $self->name())); }"></td>
            </tr>
            <tr>   
                <td class=fieldname>Description</td>
                <td><input type=text name=description value="${\ ($CGI->param('description') || ($self &&  $self->get('description'))); }"></td>
            </tr>
FORM
    # Suck in any default values passed in the parameters.
    foreach my $field (keys %{$params->{default_values}}) {
        $CGI->param($field,$params->{default_values}->{$field});
    }

    # Add a field for whatever the last thing they were looking at was.
    my $cookie_object_id = $CGI->cookie('object_id');
    my $cookie_object = new MinorImpact::Object($cookie_object_id);
    $CGI->param($cookie_object->typeName()."_id", $cookie_object->id());

    my $fields;
    if ($self) {
        $fields = $self->fields();
    } else {
        $fields = MinorImpact::Object::fields($object_type_id);
    }
    foreach my $name (keys %$fields) {
        my $field = $fields->{$name};
        my $type = $field->type();
        MinorImpact::log(8, "\$field->{name}='$field->{name}'");
        next if ($field->get('hidden') || $field->get('readonly'));
        my @params = $CGI->param($name);
        my @values;
        if (scalar(@params) > 0) {
            foreach my $field (@params) {
                push (@values, $field) unless ($field eq '');
            }
        } else {
            if ($self) {
                @values = $field->value();
            } else {
                @values = ();
            }
        }

        my $local_params = cloneHash($params);
        $local_params->{field_type} = $type;
        $local_params->{required} = $field->get('required');
        $local_params->{name} = $name;
        #foreach my $value (@values) {
        #    next if ($value eq '');
        $local_params->{value} = \@values;
        my $row = $field->formRow($local_params);
            $form .= $row;
        #}
        #if ($type =~/^\@/ || scalar(@values) == 0) {
        #    delete($local_params->{required}) unless(scalar(@values));
        #    #$local_params->{value} = '';
        #    my $row = $field->formRow($local_params);
        #    $form .= $row;
        #}
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
    MinorImpact::log(7, "ending");
    return $form;
}

sub formRow2 {
    MinorImpact::log(7, "starting");
    my $params = shift || return;


    my $name = $params->{name} || return;
    MinorImpact::log(8, "\$name='$name'");
    my $field_type = $params->{field_type} || return;
    MinorImpact::log(8, "\$field_type='$field_type'");
    my $value = $params->{value};

    my $fieldname = ucfirst($name);
    $fieldname =~s/_/ /;
    my $row = "<tr><td class=fieldname>$fieldname</td><td>\n";
    if ($field_type =~/object\[(\d+)\]$/) {
        my $object_type_id = $1;
        my $local_params = cloneHash($params);
        $local_params->{object_type_id} = $object_type_id;
        $local_params->{fieldname} = $name;
        $local_params->{selected} = $value;
        delete($local_params->{name});
        $row .= "" .  selectList($local_params);
        #$row .= "" .  selectList({object_type_id=>$object_type_id, user_id=>$user_id, selected=>$value, fieldname=>$name, required=>$params->{required}, filter=>$params->{filter}}) . "\n";
    } elsif ($field_type =~/text$/) {
        $row .= "<textarea name='$name'>$value</textarea>\n";
    } elsif ($field_type =~/boolean$/) {
        $row .= "<input type=checkbox name='$name'" . ($value?" checked":"") . ">\n";
    } else {
        $row .= "<input id='$name' type=text name='$name' value='$value'>\n";
    }
    $row .= "*" if ($params->{required});
    $row .= "</td></tr>\n";
    MinorImpact::log(7, "ending");
    return $row;
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
    MinorImpact::log(8, "object_type_id='$object_type_id',field_name='$field_name'");
    my $DB = MinorImpact::getDB();
    MinorImpact::log(8, "SELECT id FROM object_field WHERE object_type_id='$object_type_id' AND name='$field_name'");
    my $data = $DB->selectall_arrayref("SELECT id FROM object_field WHERE object_type_id=? AND name=?", {Slice=>{}}, ($object_type_id, $field_name));
    if (scalar(@{$data}) > 0) {
        return @{$data}[0]->{id};
    }
}

1;
