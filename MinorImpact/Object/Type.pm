package MinorImpact::Object::Type;

use MinorImpact;
use MinorImpact::Object;
use MinorImpact::Util;

sub new {
    my $package = shift || return;
    my $type_id = shift || return;

    my $DB = MinorImpact::getDB();
    if ($type_id !~/^\d+$/) {
        # If someone passes the string name of the type, figure that out for them.
        my $singular = $type_id;
        $singular =~s/e?s$//;
        $type_id = $DB->selectrow_array("SELECT id FROM object_type where name=? or name=? or plural=?", {Slice=>{}}, ($type_id, $singular, $type_id));
    }
    my $self = $DB->selectrow_hashref("SELECT * FROM object_type where id=?", {Slice=>{}}, ($type_id));
    bless ($self, $package);
    return $self;
}

sub id { my $self = shift || return; return $self->{id}; }
sub name {
    my $self = shift || return;
    my $params = shift || {};

    if ($params->{plural}) {
        return $self->{plural}?$self->{plural}:$self->{name}.'s';
    } else {
        return $self->{name};
    }
}

sub form2 {
    my $self = shift || return;
    my $params = shift || {};

    my $local_params = cloneHash($params);
    $local_params->{object_type_id} = $self->id();

    my $type_name = $self->name();
    my $form;
    eval {
        $form = $type_name->form($local_params);
    };
    if ($@) {
        $form = MinorImpact::Object::form($local_params);
    }

    return $form;
}

sub form {
    my $self = shift || return;
    my $params = shift || {};
    MinorImpact::log(7, "starting");

    my $object_id = $params->{object_id};
    my $user_id = $MinorImpact::SELF->getUser()->id();
    my $object;
    $object = new MinorImpact::Object($object_id) if ($object_id);
    my $object_type_id = $self->id();

    my $CGI = MinorImpact::getCGI();

    my $form = <<FORM;
    <form method=POST>
        <input type=hidden name=id value="${\ ($object_id?$object_id:''); }">
        <input type=hidden name=a value="${\ ($object_id?'edit':'add'); }">
        <input type=hidden name=type_id value="$object_type_id">
        <table class=edit>
            <tr>   
                <td class=fieldname>Name</td>
                <td><input type=text name=name value="${\ ($CGI->param('name') || ($object && $object->name())); }"></td>
            </tr>
            <tr>   
                <td class=fieldname>Description</td>
                <td><input type=text name=description value="${\ ($CGI->param('description') || ($object &&  $object->get('description'))); }"></td>
            </tr>
FORM
    # Suck in any default values passed in the parameters.
    foreach my $field (keys %{$params->{default_values}}) {
        $CGI->param($field,$params->{default_values}->{$field});
    }

    # Add a field for whatever the last thing they were looking at was.
    my $cookie_object_id = $CGI->cookie('object_id');
    if ($cookie_object_id) {
        my $cookie_object = new MinorImpact::Object($cookie_object_id);
        $CGI->param($cookie_object->typeName()."_id", $cookie_object->id());
    }

    my $fields;
    if ($object) {
        $fields = $object->fields();
    } else {
        $fields = MinorImpact::Object::fields($object_type_id);
    }
    my $script;
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
            if ($object) {
                @values = $field->value();
            } else {
                @values = ();
            }
        }

        my $local_params = cloneHash($params);
        $local_params->{field_type} = $type;
        $local_params->{required} = $field->get('required');
        $local_params->{name} = $name;
        $local_params->{value} = \@values;
        $form .= $field->formRow($local_params);
    }
    $form .= <<FORM;
            <!-- CUSTOM -->
            <tr>   
                <td class=fieldname>Tags</td>
                <td><input type=text name=tags value='${\ ($CGI->param('tags') || ($object && join(' ', $object->getTags()))); }'></td>
            </tr>
            <tr>
                <td></td>
                <td><input type=submit name=submit></td>
            </tr>
        </table>
    </form>
FORM
    $form = "<script>$script</script>$form";
    MinorImpact::log(7, "ending");
    return $form;
}


sub cmp {
    my $self = shift || return;
    my $type = shift || return;

    return $self->name() cmp $type->name();
}

1;
