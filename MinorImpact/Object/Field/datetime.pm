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

sub defaultValue {
    return '0000-00-00 00:00:00';
}

sub _input {
    my $self = shift || return;
    my $params = shift || {};

    my $name = $params->{name};
    my $value = $params->{row_value};
    my $row;
    $row .= "<input class='w3-input w3-border datepicker' id='$name' type=text name='$name' value='$value' maxlength=20";
    if ($params->{duplicate}) {
        $row .= " onchange='duplicateRow(this);'";
    }
    $row .= ">\n";
    return $row;
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
