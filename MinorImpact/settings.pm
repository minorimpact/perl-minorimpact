package MinorImpact::settings;

use MinorImpact;
use MinorImpact::Object;
use MinorImpact::Object::Type;
use MinorImpact::Util;

our @ISA = qw(MinorImpact::Object);


sub new {
    my $package = shift;
    my $params = shift;
    #MinorImpact::log('info', "starting");

    my $self = $package->SUPER::_new($params);
    bless($self, $package);

    #$self->log('info', "ending");
    return $self;
}

our $VERSION = 3;
sub dbConfig {
    #MinorImpact::log('info', "starting");

    # Verify type exists.
    my $name = __PACKAGE__;
    my $object_type_id = MinorImpact::Object::Type::add({ name => $name, plural => "settings", readonly => 1, system => 0, });
    die "Could not add object_type record\n" unless ($object_type_id);

    MinorImpact::Object::Type::setVersion($object_type_id, $VERSION);

    #MinorImpact::log('info', "ending");
    return;
}

sub form {
    my $self = shift || return;
    my $params = shift || {};

    my $local_params = cloneHash($params);
    $local_params->{no_name} = 1;
    $local_params->{no_tags} = 1;
    my $form = $self->SUPER::form($local_params);
    return $form;
}

1;

