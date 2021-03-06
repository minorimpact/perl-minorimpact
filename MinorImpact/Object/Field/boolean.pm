package MinorImpact::Object::Field::boolean;

use MinorImpact;
use MinorImpact::Object::Field;
use MinorImpact::Util;

our @ISA = qw(MinorImpact::Object::Field);

sub new {
    my $package = shift || return;
    my $data = shift || return;

    MinorImpact::log('info', "starting");

    $data->{attributes}{default_value} = 0;

    my $self = $package->SUPER::_new($data);

    bless($self, $package);
    MinorImpact::log('info', "ending");
    return $self;
}

sub toString {
    my $self = shift || return;
    #MinorImpact::log('info', "starting");

    my $value = @{$self->{data}{value}}[0];
    my $string = $value?"yes":"no";
    #MinorImpact::log('info', "ending");
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
    $row .= "<input class='w3-check' type=checkbox name='$name'" . ($value?" checked":"") . ">";

    return $row;
}

1;
