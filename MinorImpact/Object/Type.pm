package MinorImpact::Object::Type;

use strict;

use MinorImpact;
use MinorImpact::Object;
use MinorImpact::Util;

=head1 NAME

MinorImpact::Object::Type 

=cut

=head1 SYNOPSIS

=cut

=head1 DESCRIPTION

=cut

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

=cut

sub addField { 
    return MinorImpact::Object::Field::add(@_); 
} 

=head2 del

=over

=item ::del(\%params)

=back

Delete a given object type from the system.

  MinorImpact::Object::Type::del({ object_type_id => 'object'});

=head3 params

=over

=item object_type_id

The type ID of the object to the delete.  REQUIRED.

=back

=cut

sub del {
    my $params = shift || return;

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

sub deleteField { 
    return MinorImpact::Object::Field::del(@_); 
}

sub delField { 
    return MinorImpact::Object::Field::del(@_); 
}

sub fields {
    my $params = shift || return;

    #MinorImpact::log('debug', "starting");

    my $object_type_id = $params->{object_type_id} || die "No object type id defined\n";
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

    #MinorImpact::log('debug', "ending");
    return $fields;
}

=head2 setVersion

=over

=item setVersion

=back

=cut

sub setVersion {
    #MinorImpact::log('debug', "starting");
    my $object_type_id = shift || die "No object type id";
    my $version = shift || die "No version number specified";

    $object_type_id = MinorImpact::Object::typeID($object_type_id);
    die "Invalid version number" unless ($version =~/^\d+$/);
    die "Invalid object type" unless ($object_type_id =~/^\d+$/);
    #MinorImpact::log('debug', "\$object_type_id='$object_type_id', \$version='$version'");

    MinorImpact::cache("object_field_$object_type_id", {});
    MinorImpact::cache("object_type_$object_type_id", {});
    my $DB = MinorImpact::db();
    my $sql = "UPDATE object_type SET version=? WHERE id=?";
    #MinorImpact::log('debug', "sql='$sql' \@fields='$version', '$object_type_id'");
    $DB->do($sql, undef, ($version, $object_type_id)) || die $DB->errstr;
    #MinorImpact::log('debug', "ending");
}

=head1 AUTHOR

Patrick Gillan <pgillan@minorimpact.com>

=cut
1;
