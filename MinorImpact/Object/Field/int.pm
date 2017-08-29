package MinorImpact::Object::Field::int;

=head1 NAME

MinorImpact::Object::Field::int

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

    #MinorImpact::log('info', "starting");

    my $local_data = cloneHash($data);
    $local_data->{attributes}{maxlength} = 15;
    $local_data->{attributes}{default_value} = 0;

    my $self = $package->SUPER::_new($local_data);
    bless($self, $package);
    #MinorImpact::log('info', "ending");
    return $self;
}

sub validate {
    my $self = shift || return;
    my $value;

    $value = $self->SUPER::validate($value);
    die 'Invalid characters.' unless  ($value =~/^-?\d*$/);

    return $value;
}

1;
