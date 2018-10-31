package MinorImpact::Object::Field::datetime;

use strict;

use MinorImpact;
use MinorImpact::Object::Field;
use MinorImpact::Util;

our @ISA = qw(MinorImpact::Object::Field);

sub new {
    my $package = shift || return;
    my $data = shift || return;

    MinorImpact::log('debug', "starting");

    $data->{attributes}{default_value} = '0000-00-00 00:00:00';
    $data->{attributes}{maxlength} = 19;

    my $self = $package->SUPER::_new($data);
    bless($self, $package);
    MinorImpact::log('debug', "ending");
    return $self;
}

sub _input {
    my $self = shift || return;
    my $params = shift || {};

    my $name = $params->{name};
    my $value = $params->{row_value};
    my $row;
    $row .= "<input class='w3-input w3-border datepicker' id='$name' type=text name='$name' value='$value' maxlength=" . $self->{attributes}{maxlength};
    if ($params->{duplicate}) {
        $row .= " onchange='duplicateRow(this);'";
    }
    $row .= ">\n";
    return $row;
}

sub toString {
    my $self = shift || return;
    #MinorImpact::log('info', "starting");

    my $string;
    foreach my $value ($self->value()) {
        $string .= "$value,";
    }
    $string =~s/,$//;
    $string =~s/ 00:00:00//g;
    #MinorImpact::log('info', "ending");
    return $string;
}

sub validate {
    my $self = shift || return;
    my $value = shift;

    $value = '' if ($value eq '0000-00-00 00:00:00');

    if ($value =~/[^\d -:]+/) {
        die $self->name() . " contains invalid character";
    }
    $value = $self->SUPER::validate($value);

    return $value;
}

1;
