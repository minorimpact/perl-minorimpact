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

sub toString {
    my $self = shift || return;
    my $value = shift;

    my @strings;
    
    if ($value) {
        push (@strings, $value);
    } else {
        foreach my $value (@{$self->{data}{value}}) {
            push(@strings, markdown($value));
        }
    }
    return join("\n", @strings);
}

sub validate {
    my $self = shift || return;
    my $value = shift;

    die $self->name() . ": value is too large" if ($value && length($value) > 65535);
    if ((!defined($value) || (defined($value) && $value eq '')) && $self->get('required')) {
        die $self->name() . " cannot be blank";
    }
    return $value;
}

sub isText {
    return 1;
}

1;
