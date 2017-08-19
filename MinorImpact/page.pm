package MinorImpact::page;

use MinorImpact;
use MinorImpact::Object;
use MinorImpact::Object::Type;
use MinorImpact::Util;

our @ISA = qw(MinorImpact::Object);

sub new {
    my $package = shift;
    my $id = shift;
    my $params = shift || {};

    MinorImpact::log('debug', "starting(" . $id . ")");

    my $self = $package->SUPER::_new($id, $params);
    bless($self, $package);

    MinorImpact::log('debug', "ending");
    return $self;
}

our $VERSION = 4;
sub dbConfig {
    #MinorImpact::log('debug', "starting");

    # Verify type exists.
    my $name = __PACKAGE__;
    my $object_type_id = MinorImpact::Object::Type::add({ name => $name, system => 0, });
    die "Could not add object_type record\n" unless ($object_type_id);

    MinorImpact::Object::Type::addField({ object_type_id => $object_type_id, name => 'content', type=>'text', required => 1 });
    MinorImpact::Object::Type::delField({ object_type_id => $object_type_id, name => 'summary', type=>'text', required => 1 });
    MinorImpact::Object::Type::setVersion($object_type_id, $VERSION);

    #MinorImpact::log('debug', "ending");
    return;
}

sub form {
    my $self = shift || return;
    my $params = shift || {};

    my $local_params = cloneHash($params);
    my $form = $self->SUPER::form($local_params);
    return $form;
}

1;

