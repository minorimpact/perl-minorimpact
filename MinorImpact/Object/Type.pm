package MinorImpact::Object::Type;

use strict;

use JSON;
use MinorImpact;
use MinorImpact::Object;
use MinorImpact::Object::Field;
use MinorImpact::Util;

=head1 NAME

MinorImpact::Object::Type 

=cut

=head1 SYNOPSIS

=cut

=head1 DESCRIPTION

=cut

=head1 METHODS

=cut

=head2 new

=cut

sub new {
    my $package = shift;
    my $options = shift || {};
    MinorImpact::log('debug', "starting");

    my $self = {};
    my $object_type;
    if (ref($options) eq 'HASH') {
        $object_type = $options->{object_type_id};
    } elsif ($options) {
        $object_type = $options;
    }
    #die "no object_type_id specified\n" unless ($object_type);

    if ($object_type) {
        my $data = MinorImpact::cache("object_type_$object_type");
        unless ($data) {
            my $DB = MinorImpact::db() || die "no db";
            my $sql;
            if ($object_type =~/^\d+$/) {
                $sql = "SELECT * FROM object_type WHERE id=?";
            } elsif ($object_type =~/^[a-f0-9]{8}-([a-f0-9]{4}-){3}[a-f0-9]{12}$/i) {
                $object_type = lc($object_type);
                $sql = "SELECT * FROM object_type WHERE uuid=?";
            } else {
                $sql = "SELECT * from object_type WHERE name=?";
            }

            MinorImpact::log('debug', "\$sql='$sql',\$object_type='$object_type'");
            $data = $DB->selectrow_hashref($sql, undef, ($object_type)) || die $DB->errstr;
            MinorImpact::cache("object_type_$object_type", $data);
        }
        $self->{db} = $data;
    } else {
        $self->{db} = {};
    }

    bless ($self, $package);
    MinorImpact::log('debug', "ending");
    return $self;
}

=head2 dbConfig

=cut

sub dbConfig {
    my $self = shift|| return;
    my $params = shift|| {};
    MinorImpact::log('debug', "starting");

    my $type_name = $self->name();
    my $form = $type_name->dbConfig($params);

    MinorImpact::log('debug', "ending");
    return $form;
}

sub del {
    MinorImpact::Object::Type::delete(@_);
}

=head2 delete

=over

=item ->delete(\%params)

=item ::delete(\%params)

=back

Delete a given object type from the system.

  MinorImpact::Object::Type::delete({ object_type_id => 'object'});

  $TYPE->delete();

=head3 params

=over

=item object_type_id

The type ID of the object to delete. 

=back

=cut

sub delete {
    my $self = shift || return;
    my $params = shift || {};

    if (ref($self) eq 'HASH') {
        $params = $self;
        undef($self);
    }

    $params->{object_type_id} = $self->id() if ($self && !defined($params->{object_type_id}));
    my $DB = MinorImpact::db();
    my $object_type_id = MinorImpact::Object::typeID($params->{object_type_id} || $params->{type_id} || $params->{name});
    die "No object type" unless ($object_type_id);

    my $data = $DB->selectall_arrayref("SELECT * FROM object WHERE object_type_id=?", {Slice=>{}}, ($object_type_id)) || die $DB->errstr;
    foreach my $row (@$data) {
        my $object_id = $row->{id};
        MinorImpact::Object::clearCache($object_id);
        $DB->do("DELETE FROM object_tag WHERE object_id=?", undef, ($object_id)) || die $DB->errstr;
        $DB->do("DELETE FROM object_data WHERE object_id=?", undef, ($object_id)) || die $DB->errstr;
        $DB->do("DELETE FROM object_text WHERE object_id=?", undef, ($object_id)) || die $DB->errstr;
    }
    $DB->do("DELETE FROM object_field WHERE object_type_id=?", undef, ($object_type_id)) || die $DB->errstr;
    $DB->do("DELETE FROM object WHERE object_type_id=?", undef, ($object_type_id)) || die $DB->errstr;
    $DB->do("DELETE FROM object_type WHERE id=?", undef, ($object_type_id)) || die $DB->errstr;
    clearCache($params);
}

=head2 displayName

=over

=item ->displayName()

=back

Returns a "nicer" version of L<name()|MinorImpact::Object::Type/name>.

  $type = new MinorImpact::Object::Type("MinorImpact::entry");
  print $type->name() . "\n";
  # OUTPUT: MinorImpact::entry
  print $type->displayName() . "\n";
  # OUTPUT: Entry

=cut

sub displayName {
    my $self = shift || return;

    my $display_name = $self->name();
    $display_name =~s/^MinorImpact:://;
    $display_name = ucfirst($display_name);

    return $display_name;
}

=head2 fields

=over

=item ->fields(\%params)

=item ::fields(\%params);

=back

Return a hash of field objects.

=head3 params

=over

=item object_id

Pre fill the field values with data from a particular object.

  $fields = $TYPE->fields({ object_id => 445 });

=item object_type_id

  $fields = MinorImpact::Object::Type::fields({ object_type_id => 'MinorImpact::settings' });

=back

=cut

sub fields {
    my $self = shift || return;
    my $params = shift || {};

    MinorImpact::log('debug', "starting");

    if (ref($self) eq 'HASH') {
        $params = $self;
        undef($self);
    }

    if ($self) {
        MinorImpact::log('debug', "\$self->name()='" . $self->name() . "'");
    } else {
        MinorImpact::log('debug', "\$params->{object_type_id}='" . $params->{object_type_id} . "'");
    }
    $params->{object_type_id} = $self->id() if ($self && !defined($params->{object_type_id}));
    my $object_type_id = $params->{object_type_id} ||  die "No object type id defined\n";
    my $object_id = $params->{object_id};

    my $fields;
    my $DB = MinorImpact::db();
    my $data = MinorImpact::cache("object_field_$object_type_id") unless ($params->{no_cache});
    unless ($data) {
        MinorImpact::log('debug', "collecting field data for '$object_type_id' from database");
        $data = $DB->selectall_arrayref("select * from object_field where object_type_id=?", {Slice=>{}}, ($object_type_id)) || die $DB->errstr;
        MinorImpact::cache("object_field_$object_type_id", $data);
    }
    foreach my $row (@$data) {
        MinorImpact::log('debug', "\$row->{name}='" . $row->{name} . "'");
        #$row->{object_id} = $object_id if ($object_id);
        $fields->{$row->{name}} = new MinorImpact::Object::Field({ db => $row, object_id => $object_id });
    }

    MinorImpact::log('debug', "ending");
    return $fields;
}

=head2 form

=cut

sub form {
    my $self = shift|| return;
    my $params = shift|| {};
    MinorImpact::log('debug', "starting");

    $params->{object_type_id} = $self->id();
   
    my $type_name = $self->name();
    my $form = $type_name->form($params);

    MinorImpact::log('debug', "ending");
    return $form;
}

=head2 get

=cut

sub get {
    my $self = shift || return;
    my $field = shift || return;
    my $params = shift || {};

    my $value;
    if ($field eq 'uuid') {
        $value = lc($self->{db}{'uuid'});
    } else {
        $value = $self->{db}{$field};
    }

    return $value;
}

=head2 id

Returns the id of this type.

  $TYPE->id();

=cut

sub id {
    my $self = shift || return;

    return $self->{db}{id};
}

sub isNoName { return shift->{db}{no_name}; }
sub isNoTags { return shift->{db}{no_tags}; }
sub plural { return shift->{db}{plural}; }
sub isPublic { return shift->{db}{public}; }
sub isReadonly { return shift->{db}{readonly}; }
sub isSystem { return shift->{db}{system}; }

=head2 name

Return the name of this $TYPE.

  $TYPE->name();

=cut

sub name {
    my $self = shift || return;

    return $self->{db}{name} || "MinorImpact::Object";
}

=head2 toData

Returns $TYPE as a pure hash.

  $type = $TYPE->toData();

=cut

sub toData {
    my $self = shift || return;
    my $params = shift || {};

    my $data = {};

    $data->{comments} = $self->get('comments');
    $data->{id} = $self->id();
    $data->{name} = $self->name();
    $data->{no_name} = $self->get('no_name');
    $data->{no_tags} = $self->get('no_tags');
    $data->{plural} = $self->get('plural');
    $data->{public} = $self->get('public');
    $data->{readonly} = $self->isReadonly();
    $data->{system} = $self->isSystem();
    $data->{uuid} = lc($self->get('uuid'));
    $data->{version} = $self->get('version');

    my $fields = $self->fields();
    foreach my $field_name (keys %{$fields}) {
        $data->{fields}->{$field_name} = $fields->{$field_name}->toData();
    }

    return $data;
}

=head2 toString

=over

=item ->toString(\%params)

=back

Return $TYPE as a string.

  print $TYPE->toString();

=head3 params

=over

=item format

=over

=item json

Return L<MinorImpact::Object::Type::toData()|MinorImpact::Object::Type/todata> as a 
JSON formatted string.

  print $TYPE->toString({ format => 'json' });

=back

=back

=cut

sub toString {
    my $self = shift || return;
    my $params = shift || {};

    my $string = "";

    if ($params->{format} eq 'json') {
        $string = to_json($self->toData());
    } else {
        $string = $self->name();
    }

    return $string;
}

=head1 SUBROUTINES

=cut

=head2 add

=over

=item add( \%options )

=back

Add a new object type to the MinorImpact application.

=head3 options

=over

=item comments => TRUE/FALSE

Turn on comments for this object type.

Default: FALSE

=item name => STRING

The name of the object.  This must also be how it's accessed in code:

  $new_name_object = new <name>({ param1 => 'foo' });

=item no_name => BOOLEAN

If TRUE, this object will not include a "Name" field in input/edit forms. If
developer doesn't add a name value programatically during the 'new' or 
'update' functions of the inherited object class, 
'$object->type()->name() . "-" . $object-id()' will be used instead.

Default: FALSE

=item no_tags => TRUE/FALSE

If TRUE, this type will no longer support tagging.

DEFAULT: FALSE

=item public => TRUE/FALSE

This option does **not** make the objects public.  If TRUE, the user will have
the *option* of designating the type a public.  Essentially controls whether or
the the 'public' checkbox appears on object input/edit forms.

Default: FALSE

=item readonly => TRUE/FALSE

'readonly' objects are not editable by the user, and they will never be given 
option from the standard library.  These differ from 'sytem' objects by virtue
of having and owners and containing information that's relevant to said user.

Default: FALSE

=item system => TRUE/FALSE

Objects marked 'system' are meant to be core parts of the application - think
dropdowns or statuses.  They can be instantiated by any user, but only an 
admin user can add or edit them.

Default: FALSE

=back

=cut

sub add {
    my $params = shift || return;

    MinorImpact::log('debug', "starting");

    my $DB = MinorImpact::db();

    my $name = $params->{name};
    my $comments = ($params->{comments}?1:0);
    my $no_name = ($params->{no_name}?1:0);
    my $no_tags = ($params->{no_tags}?1:0);
    my $plural = $params->{plural};
    my $public = ($params->{public}?1:0);
    my $readonly = ($params->{readonly}?1:0);
    my $system = ($params->{system}?1:0);
    my $version = $params->{version};
    my $uuid = lc($params->{uuid});

    #MinorImpact::log('debug', "\$name='$name'");
    clearCache($name);
    my $object_type_id = MinorImpact::Object::typeID($name || $uuid);
    clearCache($object_type_id);
    #MinorImpact::log('debug', "\$object_type_id='$object_type_id'");
    
    if ($object_type_id) {
        my $data = $DB->selectrow_hashref("SELECT * FROM object_type WHERE id=?", {Slice=>{}}, ($object_type_id)) || die $DB->errstr();
        $DB->do("UPDATE object_type SET comments=? WHERE id=?", undef, ($comments, $object_type_id)) || die $DB->errstr unless ($data->{comments} eq $comments);
        $DB->do("UPDATE object_type SET no_name=? WHERE id=?", undef, ($no_name, $object_type_id)) || die $DB->errstr unless ($data->{no_name} eq $no_name);
        $DB->do("UPDATE object_type SET no_tags=? WHERE id=?", undef, ($no_tags, $object_type_id)) || die $DB->errstr unless ($data->{no_tags} eq $no_tags);
        $DB->do("UPDATE object_type SET plural=? WHERE id=?", undef, ($plural, $object_type_id)) || die $DB->errstr unless ($data->{plural} eq $plural);
        $DB->do("UPDATE object_type SET public=? WHERE id=?", undef, ($public, $object_type_id)) || die $DB->errstr unless ($data->{public} eq $public);
        $DB->do("UPDATE object_type SET readonly=? WHERE id=?", undef, ($readonly, $object_type_id)) || die $DB->errstr unless ($data->{readonly} eq $readonly);
        $DB->do("UPDATE object_type SET system=? WHERE id=?", undef, ($system, $object_type_id)) || die $DB->errstr unless ($data->{system} eq $system);
        if ($uuid) {
            $DB->do("UPDATE object_type SET uuid=? WHERE id=?", undef, ($uuid, $object_type_id)) || die $DB->errstr unless ($data->{uuid} eq $uuid);
        }
        $DB->do("UPDATE object_type SET version=? WHERE id=?", undef, ($version, $object_type_id)) || die $DB->errstr unless ($data->{version} eq $version);
    } else {
        die "'$name' is reserved." if (defined(indexOf(lc($name), @MinorImpact::Object::Field::valid_types, @MinorImpact::Object::Field::reserved_names)));
        my $sql = "INSERT INTO object_type (name, system, comments, no_name, no_tags, public, readonly, plural, version, uuid, create_date) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW())";
        my @fields = ($name, $system, $comments, $no_name, $no_tags, $public, $readonly, $plural, $version, ($uuid || uuid()) );
        MinorImpact::log('debug', "'$sql', (" . join(',', @fields) .")");
        $DB->do($sql, undef, @fields) || die $DB->errstr;
        $object_type_id = $DB->{mysql_insertid};
    }
    MinorImpact::log('debug', "\$object_type_id='$object_type_id'");
    my $type = new MinorImpact::Object::Type($object_type_id);

    if (defined($params->{fields})) {
        foreach my $field_name (keys %{$params->{fields}}) {
            $type->addField($params->{fields}{$field_name});
        }
    }

    MinorImpact::log('debug', "ending");
    return $type;
}

=head2 addField

=over

=item ::addField(\%options)
=item ->addField(\%options)

=back

Adds a field to the database

  MinorImpact::Object::Type::addField({ object_type_id => $object_type_id, name=>'address', type=>'string'});

See L<MinorImpact::Object::Field::add()|MinorImact::Object::Field/add> for a complete set of options.

=head3 options

=over

=item name

The field name.

=item type

The type of field.

=back

=cut

sub addField { 
    my $self = shift || return;
    my $params = shift || {};
    MinorImpact::log('debug', "starting");

    if (ref($self) eq 'HASH') {
        $params = $self;
        undef($self);
    }

    $params->{object_type_id} = $self->id() if ($self);
    
    my $field = MinorImpact::Object::Field::add($params); 
    MinorImpact::log('debug', "ending");
    return $field;
    
} 

=head2 childTypeIDs

=over

=item ->childTypeIDs()

=back

Returns a list of oject type ids that have fields of a this 
object type.

  @child_type_ids = $TYPE->childTypeIDs();

=cut

sub childTypeIDs {
    my $self = shift || return;
    my $params = shift || {};

    MinorImpact::log('debug', "starting");

    if (ref($self) eq 'HASH') {
        $params = $self;
        undef($self);
    }

    $params->{object_type_id} = $self->id() if ($self);
    die "no object type id" unless ($params->{object_type_id});

    my @child_type_ids = ();
    my $sql = "select DISTINCT(object_type_id) from object_field where type like '%object[" . $params->{object_type_id} . "]'";
    my $DB = MinorImpact::db();
    my $data = $DB->selectall_arrayref($sql, {Slice=>{}});
    foreach my $row (@$data) {
        push(@child_type_ids, $row->{object_type_id});
    }

    MinorImpact::log('debug', "ending");
    return @child_type_ids;
}

=head2 childTypes

=over

=item ->childTypes()

=back

Returns a list of oject types ids that have fields of a this 
object type.

  @child_types = $TYPE->childTypes();

=cut

sub childTypes {
    my $self = shift || return;
    my $params = shift || {};

    MinorImpact::log('debug', "starting");

    if (ref($self) eq 'HASH') {
        $params = $self;
        undef($self);
    }

    $params->{object_type_id} = $self->id() if ($self);

    my @child_types = ();
    my @child_type_ids = MinorImpact::Object::Type::childTypeIDs($params);
    foreach my $child_type_id (@child_type_ids) {
        push(@child_types, new MinorImpact::Object::Type($child_type_id));
    }
    MinorImpact::log('debug', "ending");
    return @child_types;
}

=head2 clearCache

Clear TYPE related caches.

=cut

sub clearCache {
    my $self = shift || return;

    #MinorImpact::log('debug', "starting");
    my $object_type_id;
    my $object_type_name;
    my $object_type_uuid;

    if (ref($self) eq 'HASH') {
        $object_type_id = $self->{object_type_id};
        $object_type_name = $self->{object_type_name};
    } elsif (ref($self)) {
        $object_type_id = $self->id();
        $object_type_name = $self->name();
        $object_type_uuid = lc($self->get('uuid'));
    } else {
        $object_type_id = $self;
    }

    if ($object_type_id) {
        MinorImpact::cache("object_field_$object_type_id", {});
        MinorImpact::cache("object_type_$object_type_id", {});
        MinorImpact::cache("object_type_id_$object_type_id", {});
        my $DB = MinorImpact::db();
        my $data = $DB->selectall_arrayref("SELECT * FROM object WHERE object_type_id=?", {Slice=>{}}, ($object_type_id)) || die $DB->errstr;
        foreach my $row (@$data) {
            my $object_id = $row->{id};
            MinorImpact::Object::clearCache($object_id);
        }
    }

    if ($object_type_name) {
        MinorImpact::cache("object_field_$object_type_name", {});
        MinorImpact::cache("object_type_$object_type_name", {});
        MinorImpact::cache("object_type_id_$object_type_name", {});
    }

    if ($object_type_uuid) {
        MinorImpact::cache("object_field_$object_type_uuid", {});
        MinorImpact::cache("object_type_$object_type_uuid", {});
        MinorImpact::cache("object_type_id_$object_type_uuid", {});
    }

    #MinorImpact::log('debug', "ending");
    return;
}

sub deleteField { 
    my $self = shift || return;
    my $params = shift || {};

    if (ref($self) eq 'HASH') {
        $params = $self;
        undef($self);
    }

    if ($self) {
        $params->{object_type_id} = $self->id();
    }
    
    return MinorImpact::Object::Field::delete($params); 
}

sub delField { 
    return MinorImpact::Object::Type::deleteField(@_); 
}

=head2 setVersion

=over

=item ->setVersion($version)

=back

=cut

sub setVersion {
    my $object_type_id = shift || die "No object type id";

    MinorImpact::log('debug', "starting");
    if (ref($object_type_id) eq 'MinorImpact::Object::Type') {
        $object_type_id = $object_type_id->id();
    } elsif (ref($object_type_id) eq 'HASH') {
        $object_type_id = $object_type_id->{object_type_id};
    }

    my $version = shift || die "No version number specified";

    $object_type_id = MinorImpact::Object::typeID($object_type_id);
    die "Invalid version number" unless ($version =~/^\d+$/);
    die "Invalid object type" unless ($object_type_id =~/^\d+$/);
    MinorImpact::log('debug', "\$object_type_id='$object_type_id', \$version='$version'");

    clearCache($object_type_id);
    my $DB = MinorImpact::db();
    my $sql = "UPDATE object_type SET version=? WHERE id=?";
    MinorImpact::log('debug', "sql='$sql' \@fields='$version', '$object_type_id'");
    $DB->do($sql, undef, ($version, $object_type_id)) || die $DB->errstr;
    MinorImpact::log('debug', "ending");
}

=head1 AUTHOR

Patrick Gillan <pgillan@minorimpact.com>

=cut
1;
