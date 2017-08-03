package MinorImpact::Object::Type;

use strict;

use MinorImpact;
use MinorImpact::Object;
use MinorImpact::Util;

our @reserved = ('datetime', 'string', 'boolean', 'url', 'text', 'float', 'int');

sub add {
    my $params = shift || return;

    #MinorImpact::log(7, "starting");

    my $MI = new MinorImpact();
    my $DB = $MI->db();

    my $name = $params->{name};
    my $plural = $params->{plural};
    my $system = ($params->{system}?1:0);

    my $object_type_id = MinorImpact::Object::typeID($name);
    #MinorImpact::log(8, "\$object_type_id='$object_type_id'");
    return $object_type_id if ($object_type_id);

    die "'$name' is reserved." if indexOf($name, @reserved);

    $DB->do("INSERT INTO object_type (name, system, plural, create_date) VALUES (?, ?, ?, NOW())", undef, ($name, $system, $plural)) || die $DB->errstr;

    #MinorImpact::log(7, "ending");
    return $DB->{mysql_insertid};
}

sub addField {
    my $params = shift || return;

    my $local_params = cloneHash($params);
    # We store fields that are references to other object as type object[<object id>].  This ia
    #   convenience to allow people to reference it by the type name instead of the id.
    my $name = $local_params->{name};
    my $type = $local_params->{type};
    die "Object name cannot be blank." unless ($name);
    die "Object type cannot be blank." unless ($type);

    my $array = ($type =~/^@/);
    $type =~s/^@//;

    if (!defined(indexOf($type, @reserved))) { 
        my $object_type_id = MinorImpact::Object::typeID($type);
        if ($object_type_id) {
            $local_params->{type} = "object[$object_type_id]";
            $local_params->{type} = "@" . $local_params->{type} if ($array);
        } else {
            die "'$type' is not a valid object type.";
        }
    }

    #MinorImpact::log(8, "adding field '" . $local_params->{object_type_id} . "-" . $local_params->{name} . "'");
    eval {
        MinorImpact::Object::Field::addField($local_params);
    };
    #MinorImpact::log(8, $@);
    die $@ if ($@ && $@ !~/Duplicate entry/);

    return;
}

sub setVersion {
    #MinorImpact::log(7, "starting");
    my $object_type_id = shift || die "No object type id";
    my $version = shift || die "No version number specified";

    $object_type_id = MinorImpact::Object::typeID($object_type_id);
    die "Invalid version number" unless ($version =~/^\d+$/);
    die "Invalid object type" unless ($object_type_id =~/^\d+$/);
    #MinorImpact::log(8, "\$object_type_id='$object_type_id', \$version='$version'");

    my $DB = MinorImpact::db();
    my $sql = "UPDATE object_type SET version=? WHERE id=?";
    #MinorImpact::log(8, "sql='$sql' \@fields='$version', '$object_type_id'");
    $DB->do($sql, undef, ($version, $object_type_id)) || die $DB->errstr;
    #MinorImpact::log(7, "ending");
}

1;
