package MinorImpact::reference;

=head1 NAME

MinorImpact::reference

=head1 DESCRIPTION

An object for other linking two MinorImpact objects.

=cut

use strict;

use Time::Local;

use MinorImpact::Object;
use MinorImpact::Util;
use MinorImpact::Util::String;
use MinorImpact::WWW;

our @ISA = qw(MinorImpact::Object);

sub new {
    my $package = shift;
    my $params = shift;
    MinorImpact::log('debug', "starting");

    if (ref($params) eq 'HASH') {
        my $data = $params->{data};
        if (ref($data) eq 'ARRAY') {
            $data = @$data[0];
        }

        die "no data" unless ($data);
        die "no object" unless (ref($params->{object}));
        die "no field id" unless ($params->{object_field_id});

        my $object = $params->{object};
        my $field = $object->field($params->{object_field_id});
        die "not a reference field" unless ($field->get('references'));

        my $match = 0;
        foreach my $value ($field->value()) {
            $match = 1 if($value =~/$data/);
        }
        die "no matching data" unless ($match);

        $params->{name} = trunc(ptrunc($data, 1), 30);
    }
    my $self = $package->SUPER::_new($params);
    bless($self, $package);

    MinorImpact::log('debug', "ending");
    return $self;
}

our $VERSION = 1;
sub dbConfig {
    MinorImpact::log('debug', "starting");

    # Verify type exists.
    my $name = __PACKAGE__;
    my $type = MinorImpact::Object::Type::add({ name => $name, public=>0, no_tags => 1, no_name => 1, comments => 0, readonly => 1});
    die "Could not add object_type record\n" unless ($type);

    $type->addField({ name => 'data', required => 1, type => 'text', readonly => 1 });
    $type->addField({ name => 'object', type => 'object', required => 1, readonly => 1});
    $type->addField({ name => 'object_field_id', type => 'int', required => 1, readonly => 1});
    $type->addField({ name => 'reference_object', type => 'object', required => 1, readonly => 1});

    $type->setVersion($VERSION);
    $type->clearCache();

    MinorImpact::log('debug', "ending");
    return;
}

=head2 toString

Overrides the C<list> format to use C<reference_list> instead of
C<object_list>.

See L<MinorImpact::Object::toString()|MinorImpact::Object/tostring>.

=cut

sub toString {
    my $self = shift || return;
    my $params = shift || {};

    MinorImpact::log('debug', "starting");

    if ($params->{format} eq 'list') {
        $params->{template} = 'reference_list';
    }

    my $string = $self->SUPER::toString($params);

    MinorImpact::log('debug', "ending");
    return $string;
}

=head1 AUTHOR

Patrick Gillan <pgillan@minorimpact.com>

=cut

1;
