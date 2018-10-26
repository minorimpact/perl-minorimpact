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

    my $self = {};
    if (ref($options) eq "HASH") {
    } elsif ($options) {
        my $DB = MinorImpact::db();
        my $sql = "SELECT * FROM object_type WHERE id=?";
        $self->{data} = $DB->selectrow_hashref($sql, undef, ($options)) || die $DB->errstr;
    }

    bless ($self, $package);
}

=head2 del

=over

=item ->del(\%params)

=item ::del(\%params)

=back

Delete a given object type from the system.

  MinorImpact::Object::Type::del({ object_type_id => 'object'});

  $TYPE->del();

=head3 params

=over

=item object_type_id

The type ID of the object to the delete. 

=back

=cut

sub del {
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
    MinorImpact::cache("object_field_$object_type_id", {});
    MinorImpact::cache("object_type_$object_type_id", {});

    my $data = $DB->selectall_arrayref("SELECT * FROM object WHERE object_type_id=?", {Slice=>{}}, ($object_type_id)) || die $DB->errstr;
    foreach my $row (@$data) {
        my $object_id = $row->{id};
        MinorImpact::cache("object_data_$object_id", {});
        $DB->do("DELETE FROM object_tag WHERE object_id=?", undef, ($object_id)) || die $DB->errstr;
        $DB->do("DELETE FROM object_data WHERE object_id=?", undef, ($object_id)) || die $DB->errstr;
        $DB->do("DELETE FROM object_text WHERE object_id=?", undef, ($object_id)) || die $DB->errstr;
    }
    $DB->do("DELETE FROM object_field WHERE object_type_id=?", undef, ($object_type_id)) || die $DB->errstr;
    $DB->do("DELETE FROM object WHERE object_type_id=?", undef, ($object_type_id)) || die $DB->errstr;
    $DB->do("DELETE FROM object_type WHERE id=?", undef, ($object_type_id)) || die $DB->errstr;
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
        MinorImpact::log('debug', "FOO");
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
        #MinorImpact::log('debug', "collecting field data for '$object_type_id' from database");
        $data = $DB->selectall_arrayref("select * from object_field where object_type_id=?", {Slice=>{}}, ($object_type_id)) || die $DB->errstr;
        MinorImpact::cache("object_field_$object_type_id", $data);
    }
    foreach my $row (@$data) {
        #MinorImpact::log('debug', $row->{name});
        $row->{object_id} = $object_id if ($object_id);
        $fields->{$row->{name}} = new MinorImpact::Object::Field($row);
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

    return $self->{data}{$field};
}

=head2 id

Returns the id of this type.

  $TYPE->id();

=cut

sub id {
    my $self = shift || return;

    return $self->{data}{id};
}

sub isNoName { return shift->{data}{no_name}; }
sub isNoTags { return shift->{data}{no_tags}; }
sub plural { return shift->{data}{plural}; }
sub isPublic { return shift->{data}{public}; }
sub isReadonly { return shift->{data}{readonly}; }
sub isSystem { return shift->{data}{system}; }

=head2 name

Return the name of this $TYPE.

  $TYPE->name();

=cut

sub name {
    my $self = shift || return;

    return $self->{data}{name}
}

=head2 toData

Returns $TYPE as a pure hash.

  $type = $TYPE->toData();

=cut

sub toData {
    my $self = shift || return;
    my $params = shift || {};

    my $data = {};

    $data->{id} = $self->id();
    $data->{name} = $self->name();
    $data->{no_name} = $self->get('no_name');
    $data->{no_tags} = $self->get('no_tags');
    $data->{plural} = $self->get('plural');
    $data->{public} = $self->get('public');
    $data->{readonly} = $self->isReadonly();
    $data->{system} = $self->isSystem();

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

=item name => STRING

The name of the object.  This must also be how it's accessed in code:

  $new_name_object = new <name>({ param1 => 'foo' });

=item no_name => BOOLEAN

If TRUE, this object will not include a "Name" field in input/edit forms. If
developer doesn't add a name value programatically during the 'new' or 
'update' functions of the inherited object class, 
'$object->type()->name() . "-" . $obect-id()' will be used instead.

Default: FALSE

=item no_tags => BOOLEAN

If TRUE, this type will no longer support tagging.

DEFAULT: FALSE

=item public => BOOLEAN

This option does **not** make the objects public.  If TRUE, the user will have
the *option* of designating the type a public.  Essentially controls whether or
the the 'public' checkbox appears on object input/edit forms.

Default: FALSE

=item readonly => BOOLEAN

'readonly' objects are not editable by the user, and they will never be given 
option from the standard library.  These differ from 'sytem' objects by virtue
of having and owners and containing information that's relevant to said user.

Default: FALSE

=item system => BOOLEAN

Objects marked 'system' are meant to be core parts of the application - think
dropdowns or statuses.  They can be instantiated by any user, but only an 
admin user can add or edit them.
Default: FALSE

=back

=cut

sub add {
    my $params = shift || return;

    #MinorImpact::log('debug', "starting");

    my $MI = new MinorImpact();
    my $DB = $MI->db();

    my $name = $params->{name};
    my $no_name = ($params->{no_name}?1:0);
    my $no_tags = ($params->{no_tags}?1:0);
    my $plural = $params->{plural};
    my $public = ($params->{public}?1:0);
    my $readonly = ($params->{readonly}?1:0);
    my $system = ($params->{system}?1:0);

    #MinorImpact::log('debug', "\$name='$name'");
    my $object_type_id = MinorImpact::Object::typeID($name);
    #MinorImpact::log('debug', "\$object_type_id='$object_type_id'");
    
    if ($object_type_id) {
        MinorImpact::cache("object_field_$object_type_id", {});
        MinorImpact::cache("object_type_$object_type_id", {});
        my $data = $DB->selectrow_hashref("SELECT * FROM object_type WHERE id=?", {Slice=>{}}, ($object_type_id)) || die $DB->errstr();
        $DB->do("UPDATE object_type SET no_name=? WHERE id=?", undef, ($no_name, $object_type_id)) || die $DB->errstr unless ($data->{no_name} eq $no_name);
        $DB->do("UPDATE object_type SET no_tags=? WHERE id=?", undef, ($no_tags, $object_type_id)) || die $DB->errstr unless ($data->{no_tags} eq $no_tags);
        $DB->do("UPDATE object_type SET plural=? WHERE id=?", undef, ($plural, $object_type_id)) || die $DB->errstr unless ($data->{plural} eq $plural);
        $DB->do("UPDATE object_type SET public=? WHERE id=?", undef, ($public, $object_type_id)) || die $DB->errstr unless ($data->{public} eq $public);
        $DB->do("UPDATE object_type SET readonly=? WHERE id=?", undef, ($readonly, $object_type_id)) || die $DB->errstr unless ($data->{readonly} eq $readonly);
        $DB->do("UPDATE object_type SET system=? WHERE id=?", undef, ($system, $object_type_id)) || die $DB->errstr unless ($data->{system} eq $system);
        return $object_type_id;
    }

    die "'$name' is reserved." if (defined(indexOf(lc($name), @MinorImpact::Object::Field::valid_types, @MinorImpact::Object::Field::reserved_names)));

    $DB->do("INSERT INTO object_type (name, system, no_name, no_tags, public, readonly, plural, create_date) VALUES (?, ?, ?, ?, ?, ?, ?, NOW())", undef, ($name, $system, $no_name, $no_tags, $public, $readonly, $plural)) || die $DB->errstr;

    #MinorImpact::log('debug', "ending");
    return $DB->{mysql_insertid};
}

=head2 addField

=over

=item addField(\%options)

=back

Adds a field to the database

  MinorImpact::Object::Type::addField({ object_type_id => $object_type_id, name=>'address', type=>'string'});

=head3 options

=over

=item name

The field name.

=item type

The type of field.

=back

=cut

sub addField { 
    return MinorImpact::Object::Field::add(@_); 
} 


sub deleteField { 
    return MinorImpact::Object::Field::del(@_); 
}

sub delField { 
    return MinorImpact::Object::Field::del(@_); 
}

=head2 setVersion

=over

=item setVersion

=back

=cut

sub setVersion {
    MinorImpact::log('debug', "starting");
    my $object_type_id = shift || die "No object type id";
    my $version = shift || die "No version number specified";

    $object_type_id = MinorImpact::Object::typeID($object_type_id);
    die "Invalid version number" unless ($version =~/^\d+$/);
    die "Invalid object type" unless ($object_type_id =~/^\d+$/);
    MinorImpact::log('debug', "\$object_type_id='$object_type_id', \$version='$version'");

    MinorImpact::cache("object_field_$object_type_id", {});
    MinorImpact::cache("object_type_$object_type_id", {});
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
