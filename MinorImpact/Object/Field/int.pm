package MinorImpact::Object::Field::int;

=head1 NAME

MinorImpact::Object::Field::int

=head1 METHODS

=cut

use strict;

use MinorImpact;
use MinorImpact::Object::Field;

our @ISA = qw(MinorImpact::Object::Field);

sub new {
    my $package = shift || return;
    my $data = shift || return;

    #MinorImpact::log('info', "starting");

    $data->{attributes}{maxlength} = 15;
    $data->{attributes}{default_value} = 0;

    my $self = $package->SUPER::_new($data);
    bless($self, $package);
    #MinorImpact::log('info', "ending");
    return $self;
}

sub validate {
    my $self = shift || return;
    my $value = shift;

    $value = $self->SUPER::validate($value);
    die 'Invalid characters.' unless  ($value =~/^-?\d*$/);

    return $value;
}

=head1 AUTHOR

Patrick Gillan <pgillan@minorimpact.com>

=cut

1;
