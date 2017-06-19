package MinorImpact::Object::Field::boolean;

use MinorImpact;
use MinorImpact::Object::Field;

our @ISA = qw(MinorImpact::Object::Field);

sub new {
    my $package = shift || return;
    my $data = shift || return;

    MinorImpact::log(7, "starting");
    my $self = $package->SUPER::_new($data);

    bless($self, $package);
    MinorImpact::log(7, "ending");
    return $self;
}

sub toString {
    my $self = shift || return;
    MinorImpact::log(7, "starting");

    my $value = @{$self->{data}{value}}[0];
    my $string = $value?"yes":"no";
    MinorImpact::log(7, "ending");
    return $string;
}

sub validate {  
    my $self = shift || return;
    my $value = shift;

    $value = $self->SUPER::validate($value);

    if ($field_type eq 'boolean') {
        $value = ($value?1:0);
    }
    return $value;
}


1;
