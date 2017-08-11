package MinorImpact::Object::Field::datetime;

use MinorImpact;
use MinorImpact::Object::Field;

our @ISA = qw(MinorImpact::Object::Field);

sub new {
    my $package = shift || return;
    my $data = shift || return;

    #MinorImpact::log(7, "starting");

    my $local_data = cloneHash($data);
    $local_data->{attributes}{default_value} = '0000-00-00 00:00:00';
    $local_data->{attributes}{maxlength} = 20;

    my $self = $package->SUPER::_new($local_data);
    bless($self, $package);
    #MinorImpact::log(7, "ending");
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
