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

sub update {
    my $self = shift || return;

    my @values = MinorImpact::Object::Field::unpackValues(@_);
    my @new_values = ();
    foreach my $value (@values) {
        #if ($value =~/^[a-f0-9]{8}-([a-f0-9]{4}-){3}[a-f0-9]{12}$/i) {
        unless ($value =~/^\d+$/) {
            my $object = new MinorImpact::Object($value) || die "invalid object '$value'";
            push(@new_values, $object->id());
        } else {
            push(@new_values, $value);
        }
    }
    return $self->SUPER::update(@new_values);
}

=head2 validate

=cut

sub validate {
    my $self = shift || return;
    my $value = shift;

    MinorImpact::log('debug', "starting");


    #$valid = 1 if ($value =~/^\d+$/);

    my $object = new MinorImpact::Object($value);
    unless ($object) {
        MinorImpact::log('debug', "ending(invalid)");
        die "invalid object '$value'";
    }

    MinorImpact::log('debug', "ending(valid)");
    return 1;
}

=head1 AUTHOR

Patrick Gillan <pgillan@minorimpact.com>

=cut

1;
