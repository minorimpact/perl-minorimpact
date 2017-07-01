package MinorImpact::Object::Field::datetime;

use MinorImpact;
use MinorImpact::Object::Field;

our @ISA = qw(MinorImpact::Object::Field);

sub new {
    my $package = shift || return;
    my $data = shift || return;

    #MinorImpact::log(7, "starting");
    my $self = $package->SUPER::_new($data);

    bless($self, $package);
    #MinorImpact::log(7, "ending");
    return $self;
}

sub toString {
    my $self = shift || return;
    #MinorImpact::log(7, "starting");

    my $string;
    foreach my $value ($self->value()) {
        $string .= "$value,";
    }
    $string =~s/,$//;
    $string =~s/ 00:00:00//g;
    #MinorImpact::log(7, "ending");
    return $string;
}

1;
