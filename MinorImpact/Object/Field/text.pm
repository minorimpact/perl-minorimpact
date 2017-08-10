package MinorImpact::Object::Field::text;

use Text::Markdown 'markdown';

use MinorImpact;
use MinorImpact::Object::Field;

our @ISA = qw(MinorImpact::Object::Field);

sub new {
    my $package = shift || return;
    my $data = shift || return;

    #MinorImpact::log(7, "starting");
    my $self = $package->SUPER::_new($data);

    bless($self, $package);

    $self->{attributes}{maxlength} = 65535;
    $self->{attributes}{markdown} = 1;
    $self->{attributes}{is_text} = 1;
    #MinorImpact::log(7, "ending");
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
