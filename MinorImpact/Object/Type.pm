package MinorImpact::Object::Type;

use strict;

use MinorImpact;
use MinorImpact::Object;
use MinorImpact::Util;

sub add {
    my $params = shift || return;

    #MinorImpact::log(7, "starting");

    my $MI = new MinorImpact();
    my $DB = $MI->db();

    my $name = $params->{name};
    my $plural = $params->{plural};
    my $readonly = ($params->{readonly}?1:0);
    my $system = ($params->{system}?1:0);

    my $object_type_id = MinorImpact::Object::typeID($name);
    #MinorImpact::log(8, "\$object_type_id='$object_type_id'");
    
    if ($object_type_id) {
        MinorImpact::cache("object_field_$object_type_id", {});
        MinorImpact::cache("object_type_$object_type_id", {});
        my $data = $DB->selectrow_hashref("SELECT * FROM object_type WHERE id=?", {Slice=>{}}, ($object_type_id)) || die $DB->errstr();
        $DB->do("UPDATE object_type SET plural=? WHERE id=?", undef, ($plural, $object_type_id)) || die $DB->errstr unless ($data->{plural} eq $plural);
        $DB->do("UPDATE object_type SET readonly=? WHERE id=?", undef, ($readonly, $object_type_id)) || die $DB->errstr unless ($data->{readonly} eq $readonly);
        $DB->do("UPDATE object_type SET system=? WHERE id=?", undef, ($system, $object_type_id)) || die $DB->errstr unless ($data->{system} eq $system);
        return $object_type_id;
    }

    die "'$name' is reserved." if (defined(indexOf(lc($name), @MinorImpact::Object::Field::valid_types, @MinorImpact::Object::Field::reserved_names)));

    $DB->do("INSERT INTO object_type (name, system, readonly, plural, create_date) VALUES (?, ?, ?, ?, NOW())", undef, ($name, $system, $readonly, $plural)) || die $DB->errstr;

    #MinorImpact::log(7, "ending");
    return $DB->{mysql_insertid};
}

sub del {
    my $params = shift || return;

    my $DB = MinorImpact::db();
    my $object_type_id = $params->{object_type_id};
    unless ($object_type_id) {
        $object_type_id = MinorImpact::Object::typeID($params->{name});
    }
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

sub addField {
    return MinorImpact::Object::Field::add(@_);
}

sub delField {
    return MinorImpact::Object::Field::del(@_);
}

sub fields {
    my $params = shift || return;

    #MinorImpact::log(7, "starting");

    my $object_type_id = $params->{object_type_id} || die "No object type id defined\n";
    my $object_id = $params->{object_id};

    my $fields;
    my $DB = MinorImpact::db();
    my $data = MinorImpact::cache("object_field_$object_type_id");
    unless ($data) {
        $data = $DB->selectall_arrayref("select * from object_field where object_type_id=?", {Slice=>{}}, ($object_type_id)) || die $DB->errstr;
        MinorImpact::cache("object_field_$object_type_id", $data);
    }
    foreach my $row (@$data) {
        #MinorImpact::log(8, $row->{name});
        $row->{object_id} = $object_id if ($object_id);
        $fields->{$row->{name}} = new MinorImpact::Object::Field($row);
    }

    #MinorImpact::log(7, "ending");
    return $fields;
}

sub setVersion {
    #MinorImpact::log(7, "starting");
    my $object_type_id = shift || die "No object type id";
    my $version = shift || die "No version number specified";

    $object_type_id = MinorImpact::Object::typeID($object_type_id);
    die "Invalid version number" unless ($version =~/^\d+$/);
    die "Invalid object type" unless ($object_type_id =~/^\d+$/);
    #MinorImpact::log(8, "\$object_type_id='$object_type_id', \$version='$version'");

    MinorImpact::cache("object_field_$object_type_id", {});
    MinorImpact::cache("object_type_$object_type_id", {});
    my $DB = MinorImpact::db();
    my $sql = "UPDATE object_type SET version=? WHERE id=?";
    #MinorImpact::log(8, "sql='$sql' \@fields='$version', '$object_type_id'");
    $DB->do($sql, undef, ($version, $object_type_id)) || die $DB->errstr;
    #MinorImpact::log(7, "ending");
}

1;
