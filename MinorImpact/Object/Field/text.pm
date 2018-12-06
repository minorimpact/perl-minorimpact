package MinorImpact::Object::Field::text;

use MinorImpact;
use MinorImpact::Util;
use MinorImpact::Object::Field;

our @ISA = qw(MinorImpact::Object::Field);

sub new {
    my $package = shift || return;
    my $data = shift || return;

    #MinorImpact::log('info', "starting");

    $data->{attributes}{maxlength} = 16777215;
    $data->{attributes}{is_text} = 1;
    $data->{attributes}{string_value_seperator} = "\n";

    my $self = $package->SUPER::_new($data);
    bless($self, $package);

    #MinorImpact::log('info', "ending");
    return $self;
}

sub _input {
    my $self = shift || return;
    my $params = shift || {};

    my $name = $self->name() || return;
    my $value = $params->{row_value};

    my $row;
    $row .= "<textarea class='w3-input w3-border' name='$name' rows=15";
    if ($params->{duplicate}) {
        $row .= " onchange='duplicateRow(this);'";
    }
    $row .= ">$value</textarea>\n";

    return $row;
}

1;
