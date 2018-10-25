package MinorImpact::settings;

use MinorImpact;
use MinorImpact::Object;
use MinorImpact::Object::Type;
use MinorImpact::Util;

our @ISA = qw(MinorImpact::Object);

sub new {
    my $package = shift;
    my $params = shift;
    MinorImpact::log('debug', "starting");

    my $self = $package->SUPER::_new($params);
    bless($self, $package);

    MinorImpact::log('debug', "ending");
    return $self;
}

our $VERSION = 6;
sub dbConfig {
    MinorImpact::log('debug', "starting");

    # Verify type exists.
    my $name = __PACKAGE__;
    my $object_type_id = MinorImpact::Object::Type::add({ name => $name, plural => "settings", readonly => 1, system => 1, no_name => 1, no_tags => 1 });
    die "Could not add object_type record\n" unless ($object_type_id);

    MinorImpact::Object::Type::setVersion($object_type_id, $VERSION);

    MinorImpact::log('debug', "ending");
    return;
}

1;

