package MinorImpact::Object;

use Data::Dumper;
use JSON;
use Text::Markdown 'markdown';

use MinorImpact;
use MinorImpact::Container;
use MinorImpact::Util;
use MinorImpact::Object::Field;
use MinorImpact::Object::Search;

my $OBJECT_CACHE;

sub new {
    my $package = shift || return;
    my $id = shift || return;

    #MinorImpact::log(7, "starting(" . $id . ")");
    my $DB = MinorImpact::getDB();
    my $object;

    return $OBJECT_CACHE->{$id} if ($OBJECT_CACHE->{$id});

    eval {
        my $data;
        if (ref($id) eq "HASH") {
            $data = $DB->selectrow_hashref("SELECT name, system FROM object_type ot WHERE ot.id=?", undef, ($id->{type_id})) || die $MinorImpact::SELF->{DB}->errstr;
        } else {
            $data = $DB->selectrow_hashref("SELECT ot.name, ot.system FROM object o, object_type ot WHERE o.object_type_id=ot.id AND o.id=?", undef, ($id)) || die $DB->errstr;
        }
        my $type_name = $data->{name}; 
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
    #
    #MinorImpact::log(8, "\$object doesn't exist") unless ($object);
    #MinorImpact::log(7, "ending($id)");

    die "permission denied" unless ($object->validateUser());

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
        # TODO: isn't this just duplicating the fields() and update() functionatlity? Sure, we should independent
        #   verification before we create the object (maybe? Hiw is this being done during update?) but then how is this different
        #   than just creating the object and passing the values to update()?  Maybe because without the rest of the data added to the
        #   database, update doesn't work?  Look into all of this.
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
                $self->{DB}->do("INSERT INTO object_tag(object_id, name) VALUES (?, ?)", undef, ($object_id, $tag)) if (trim(\$tag));
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
sub name { 
    my $self = shift || return; 
    my $params = shit || {};

    return $self->get('name', $params); 
}

# LEGACY
sub user_id { 
    my $self = shift || return; 
    return $self->userID(); 
}

sub userID { 
    my $self = shift || return; 
    return $self->get('user_id'); 
}   

sub selectList {
    my $self = shift || return;
    my $params = shift || {};

    #MinorImpact::log(7, "starting");
    my $local_params = cloneHash($params);
    $local_params->{debug} .= "Object::selectList();";
    if (ref($self) eq 'HASH') {
        $local_params = cloneHash($self);
        $local_params->{debug} .= "Object::selectList();";
        if ($local_params->{selected}) {
            $self = new MinorImpact::Object($local_params->{selected});
            $local_params->{user_id} = $self->userID() if ($self && !$local_params->{user_id});
            delete($local_params->{user_id}) if ($self->isSystem());
        } else {
            undef $self;
        }
    } elsif (ref($self)) {
        $local_params->{user_id} ||= $self->userID();
        $local_params->{selected} = $self->id() unless ($local_params->{selected});
        delete($local_params->{user_id}) if ($self->isSystem());
    }

    my $select = "<select id='$local_params->{fieldname}' name='$local_params->{fieldname}'";
    if ($local_params->{duplicate}) {
        $select .= " onchange='duplicateRow(this);'";
    }
    $select .= ">\n";
    $select .= "<option></option>\n" unless ($local_params->{required});
    $local_params->{sort} = 1;
    if ($local_params->{object_type_id} && $local_params->{user_id}) {
        # TODO: I've added system objects, so I don't want to limit the results to just
        #   what's owned by the current user, so I need to query the database about this
        #   type and change my tune if these belong to everyone.
        delete($local_params->{user_id}) if (MinorImpact::Object::isSystem($local_params->{object_type_id}));
    }
    my @objects = MinorImpact::Object::Search::search($local_params);
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
            if ($params->{truncate} =~/^\d+$/) {
                $value = trunc($value, $params->{truncate});
            }
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
        $object_type_id = $self->typeID();
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
        $type_id = $self->typeID();
    } else {
        $type_id = $self;
        if (!$type_id) {
            if ($MinorImpact::SELF->{conf}{default}{default_object_type}) {
                return MinorImpact::Object::typeID($MinorImpact::SELF->{conf}{default}{default_object_type});
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
    return $DB->selectall_arrayref("$select $where", {Slice=>{}});
}

sub typeName {
    my $self = shift || return;
    my $params = shift || {};

    #MinorImpact::log(7, "starting");

    my $type_id;
    if (ref($self) eq 'HASH') {
        $params = $self;
        undef($self);
        $type_id = $params->{object_type_id} || $params->{type_id};
    } elsif (ref($self)) {
        $type_id = $params->{object_type_id} || $params->{type_id} || $self->typeID();
    } elsif($self) {
        $type_id = $self;
        undef($self);
    }
    #MinorImpact::log(8, "\$type_id='$type_id'");

    my $type_name;
    my $plural_name;
    if ($self && $type_id == $self->typeID()) {
        $type_name = $self->{type_data}->{name};
        $plural_name = $self->{type_data}->{plural};
    } else {
        my $DB = MinorImpact::getDB();
        my $where = "name=?";
        if ($type_id =~/^[0-9]+$/) {
            $where = "id=?";
        }

        my $sql = "select name, plural from object_type where $where";
        #MinorImpact::log(8, "sql=$sql, ($type_id)");
        ($type_name, $plural_name) = $DB->selectrow_array($sql, undef, ($type_id));
    }

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
    $self->{type_data} = $self->{DB}->selectrow_hashref("select * from object_type where id=?", undef, ($self->typeID()));

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

    my $data = $self->{DB}->selectall_arrayref("select * from object_field where type like '%object[" . $self->typeID() . "]'", {Slice=>{}});
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

sub log {
    my $self = shift || return;
    my $level = shift || return;
    my $message = shift || return;

    MinorImpact::log($level, $message);
    return;
}

sub getChildTypes {
    my $self = shift || return;
    my $params = shift || {};

    #MinorImpact::log(7, "starting");
    $params->{object_type_id} = $params->{type_id} if ($params->{type_id} && !$params->{object_type_id});

    my @childTypes;
    my $data = $self->{DB}->selectall_arrayref("select DISTINCT object_type_id from object_field where type like '%object[" . $self->typeID() . "]'", {Slice=>{}});
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
    $local_params->{debug} .= "Object::getChildren();";
    #my $user_id = $self->userID();

    $local_params->{where} = " AND object_data.object_field_id IN (SELECT id FROM object_field WHERE type LIKE ?) AND object_data.value = ?";
    $local_params->{where_fields} = [ "%object[" . $self->typeID() . "]", $self->id() ];

    return MinorImpact::Object::Search::search($local_params);
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
            my $t;
            $TT->process('tag', {tag=>$tag}, \$t) || die $TT->error();
            $string .= $t;
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
        $TT->process('object_list', { object => $self }, \$string) || die $TT->error();
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
    $data->{type_id} = $self->typeID();
    my $fields = $self->fields();
    foreach my $name (keys %$fields) {
        my $field = $fields->{$name};
        my @values = $field->value();
        if ($field->isArray()) {
            $data->{$name} = \@values;
        } else {
            $data->{$name} = $values[0];
        }
    }
    @{$data->{tags}} = ($self->getTags());
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

    my $CGI = MinorImpact::getCGI();
    my $TT = MinorImpact::getTT();
    my $user = MinorImpact::getUser() || die "Invalid user.";
    my $user_id = $user->id();

    my $local_params = cloneHash($params);
    $local_params->{debug} .= "Object::form();";
    my $type;
    if ($self) {
        $local_params->{object_type_id} = $self->typeID();
    } elsif (!($local_params->{object_type_id} || $local_params->{type_id})) {
        die "Can't create a form with no object_type_id.\n";
    }
    my $object_type_id = $local_params->{object_type_id} || $local_params->{type_id};


    my $form;
 
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

    my $fields;
    if ($self) {
        $fields = $self->{object_data};
    } else {
        $fields = MinorImpact::Object::fields($object_type_id);
    }
    my $script;
    my $form_fields;
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
        $form_fields .= $field->formRow($local_params);
    }

    $TT->process('object_form', {
                                    form_fields    => $form_fields,
                                    javascript     => $script,
                                    object         => $self,
                                    object_type_id => $object_type_id,
                                    name           => ($CGI->param('name') || ($self && $self->name())),
                                    no_name        => $local_params->{no_name},
                                    tags           => ($CGI->param('tags') || ($self && join(' ', $self->getTags()))),
                                }, \$form) || die $TT->error();
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

# This is stupid, it's always going to be '1' per tag for a given object. But I'm leaving it for the selectall_hashref example.
sub getTagCounts {
    my $self = shift || return;

    my $DB = MinorImpact::getDB();
    my $VAR1 = $DB->selectall_hashref("select name, count(*) as tag_count from object_tag where object_id=? group by name", 'name', undef, ($self->id())) || die $DB->errstr;
    #$VAR1 = {
    #      'friend' => {
    #                    'tag_count' => '1',
    #                    'name' => 'friend'
    #                  },
    #      'work' => {
    #                  'tag_count' => '1',
    #                  'name' => 'work'
    #                },
    #      'roommate' => {
    #                      'tag_count' => '1',
    #                      'name' => 'roommate'
    #                    }
    #    };
    return $VAR1;
}

sub isSystem {
    my $self = shift || {};

    # TODO: You know that point where you get too tired to care any more, and however good something ends
    #   up being depends entirely on how high you were able get before that point?  I think I'm there.
    #   This whole system relies on objects being both substantiated and unsubstantiated, using the same
    #   functions in both cases simply using context to work out whether or not I'm a real boy or a ghost.
    #   In this case, I'm getting meta information about the type of object that will be created based on...
    #   shit.  That's not even what's happening here, this is base object, so anything calling this doesn't
    #   event know what type of object it's *going* to be? Wait, that can't be true, right? What the fuck is
    #   going on here?!
    if ($self =~/^\d+$/) {
        my $DB = MinorImpact::getDB();
        my $data = $DB->selectrow_hashref("SELECT name, system FROM object_type ot WHERE ot.id=?", undef, ($self)) || die $DB->errstr;
        return $data->{system};
    } elsif (ref($self)) {
        return ($self->{type_data}->{system}?1:0);
    }
}

# Take the same search parameters generated by MinorImpact::Object::Search::parseSearchString()
#   and check the 
sub match {
    my $self = shift || return;
    my $params = shift || {};

    MinorImpact::log(7, "starting(" . $self->id() . ")");

    # Check tags first.
    if ($params->{tag}) {
        my @tags = $self->getTags();
        foreach my $tag (split(/,/, $params->{tag})) {
            if ($tag =~/^!(\w+)$/) {
                # We found it - that's bad.
                return if (indexOf($1, @tags));
            }
            # We didn't find it - that's bad.
            return unless(indexOf($tag, @tags));
        }
    }

    if ($params->{text}) {
        my $test = $params->{text};
        my $match = 1;
        if ($test =~/^!(.*)$/) {
            $test = $1;
            $match = 0;
        }

        my $fields = $self->fields();
        foreach my $field_name (keys %{$fields}) {
            foreach my $value ($fields->{$field_name}->value()) {
                next if ($value =~/^\d+$/);
                # Once anything matches, the game's over.  We just have to 
                #   determine if that was a good thing or a bad (!) thing.
                if ($value =~/$test/) {
                    return $match;
                }
            }
        }
        # Return the opposite of whatever $match was, because that was
        #  set to whether we did or did not (!) want to find what
        #  we were looking for.
        return ($match?0:1);
    }

    return 1;
}
        

sub validateUser {
    my $self = shift || return;
    my $params = shift || {};

    #MinorImpact::log(8, "starting(" . $self->id() . ")");

    return true if ($self->isSystem());

    if ($params->{proxy_object_id} && $params->{proxy_object_id} =~/^\d+$/ && $params->{proxy_object_id} != $self->id()) {
        my $object = new MinorImpact::Object($params->{proxy_object_id}) || die "Cannot create proxy object for validation.";
        return $object->validateUser($params);
    }

    my $test_user = $params->{user} || MinorImpact::getUser();
    return unless ($test_user && ref($test_user) eq 'MinorImpact::User');
    #MinorImpact::log(8, "\$test_user->id()='" .$test_user->id() . "'");

    return ($test_user->id() && $self->userID() && ($test_user->id() eq $self->userID()));
}

1;
