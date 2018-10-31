package MinorImpact::Object::Field::password;

=head1 NAME

MinorImpact::Object::Field::password

=head1 METHODS

=cut

use strict;

use MinorImpact;
use MinorImpact::Object::Field;

our @ISA = qw(MinorImpact::Object::Field);

sub new {
    my $package = shift || return;
    my $data = shift || return;


    $data->{attributes}{maxlength} = 16;

    my $self = $package->SUPER::_new($data);
    bless($self, $package);
    return $self;
}

sub _input {
    my $self = shift || return;
    my $params = shift || {};

    my $name = $self->name() || return;

    my $row = "<input class='w3-input w3-border' type=password name='$name' id='$name'>";

    return $row;
}

sub validate {
    my $self = shift || return;
    my $value = shift;

    $value = $self->SUPER::validate($value);
    die 'Too short' unless (length($value) > 7);

    return $value;
}

=head1 AUTHOR

Patrick Gillan <pgillan@minorimpact.com>

=cut

1;
