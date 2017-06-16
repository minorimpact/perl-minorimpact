package MinorImpact::Object::Type;

use MinorImpact;

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

sub cmp {
    my $self = shift || return;
    my $type = shift || return;

    return $self->id() <=> $type->id();
}

1;
