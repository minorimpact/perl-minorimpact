package MinorImpact::Object::Field;

use MinorImpact;
use MinorImpact::Object::Field::url;

sub new {
    my $package = shift || return;
    my $field_type = shift || return;
    my $data = shift || return;

    MinorImpact::log(7, "starting");
    my $self;
    eval {
        MinorImpact::log(7, "\$field_type=$field_type");
        $self = "MinorImpact::Object::Field::$field_type"->new($data) if ($field_type);
    };
    if ($@ =~/^error:/) {
        my $error = $@;
        $error =~s/ at \/.*$//;
        $error =~s/^error://;
        die $error;
    }

    unless ($self) {
        $self = MinorImpact::Object::Field::_new($package, $data);
    }
    MinorImpact::log(7, "ending");
    return $self;
}

sub _new {
    my $package = shift || return;
    my $data = shift || return;
    MinorImpact::log(7, "starting");

    my $self = {};
    bless($self, $package);

    $self->{data} = $data;
    MinorImpact::log(7, "ending");
    return $self;
}

sub fieldname {
    my $self = shift || return;

    return $self->{data}{name};
}

sub displayname {
    my $self = shift || return;

    my $displayname = $self->name();
    $displayname =~s/_id$//;
    $displayname =~s/_date$//;
    $displayname = ucfirst($displayname) . " (f)";
    return $displayname;
}

sub id { my $self = shift || return; return $self->{data}{id}; }
sub name { my $self = shift || return; return $self->{data}{name}; }
sub toString { my $self = shift || return; return $self->{data}{value}; }
sub value { my $self = shift || return; return $self->{data}{value}; }

1;
