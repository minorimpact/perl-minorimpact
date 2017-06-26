package MinorImpact::Object::Field::boolean;

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

sub addValue {
    my $self = shift || return;
    my $data = shift || return;

    $data->{value} = ($data->{value}?1:0);
    $self->SUPER::addValue($data);
}

sub toString {
    my $self = shift || return;
    #MinorImpact::log(7, "starting");

    my $value = @{$self->{data}{value}}[0];
    my $string = $value?"yes":"no";
    #MinorImpact::log(7, "ending");
    return $string;
}

sub isArray() {
    my $self = shift || return;
    return 0;
}

sub validate {  
    my $self = shift || return;
    my $value = shift;

    #$value = $self->SUPER::validate($value);

    $value = ($value?1:0);

    return $value;
}

sub _input {
    my $self = shift || return;
    my $params = shift || {};

    my $name = $self->name() || return;
    my $value = $params->{row_value};

    my $row;
    $row .= "<input type=checkbox name='$name'" . ($value?" checked":"") . ">\n";

    return $row;
}

1;
