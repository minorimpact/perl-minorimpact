package MinorImpact::Object::Type;

use MinorImpact;

sub new {
    my $package = shift;
    my $params = shift;

    my $self = {};
    bless ($self, $package);
    return $self;
}
