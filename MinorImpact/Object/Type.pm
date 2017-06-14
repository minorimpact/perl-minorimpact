package MinorImpact::Object::Type;

use MinorImpact;

sub new {
    my $package = shift;
    my $params = shift || {};

    unless (ref($params)) {
        my $type_id = $params;
        $params = {};
        $params->{type_id} = $type_id;
    }

    #my $self = {};
    my $DB = MinorImpact::getDB();
    my $self = $DB->selectrow_hashref("SELECT * FROM object_type where id=?", {Slice=>{}}, ($params->{type_id}));
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

1;
