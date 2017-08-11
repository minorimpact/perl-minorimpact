package MinorImpact::Object::Field::float;

=head1 NAME

MinorImpact::Object::Field::float

=head1 METHODS

=over 4

=cut

use strict;

use MinorImpact;
use MinorImpact::Object::Field;

our @ISA = qw(MinorImpact::Object::Field);

sub new {
    my $package = shift || return;
    my $data = shift || return;

    #MinorImpact::log(7, "starting");
    my $local_data = cloneHash($data);
    $local_data->{attributes}{maxlength} = 15;
    $local_data->{attributes}{default_value} = '0.0';

    my $self = $package->SUPER::_new($local_data);
    bless($self, $package);

    #MinorImpact::log(7, "ending");
    return $self;
}

sub validate {
    my $self = shift || return;
    my $value;

    $value = $self->SUPER::validate($value);
    die 'Invalid characters.' unless ($value =~/^-?[\d]*\.?[\d]*$/);

    return $value;
}

1;
