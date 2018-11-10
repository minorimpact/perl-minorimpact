package MinorImpact::Object::Field::object;

=head1 NAME

MinorImpact::Object::Field::object

=head1 METHODS

=cut

use strict;

use MinorImpact;
use MinorImpact::Object::Field;

our @ISA = qw(MinorImpact::Object::Field);

=head2 new

=cut

sub new {
    my $package = shift || return;
    my $data = shift || return;

    #MinorImpact::log('debug', "starting");

    my $self = $package->SUPER::_new($data);
    bless($self, $package);
    #MinorImpact::log('debug', "ending");
    return $self;
}

sub toString {
    my $self = shift || return;
    my $params = shift || {};

    my $string;

    $string = $self->SUPER::toString($params);
    return $string;
}

=head2 validate

=cut

sub validate {
    my $self = shift || return;
    my $value = shift;

    MinorImpact::log('debug', "starting");

    my $object;
    my $valid = 0;

    $valid = 1 if ($value =~/^\d+$/);

    $object = new MinorImpact::Object($value) if ($valid);

    $valid = $object?1:0;

    MinorImpact::log('debug', "ending(" . ($valid?"valid":"invalid") . ")");
    return $valid;
}

=head1 AUTHOR

Patrick Gillan <pgillan@minorimpact.com>

=cut

1;
