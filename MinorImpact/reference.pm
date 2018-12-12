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
        die "no object" unless ($params->{object});
        die "no object" unless ($params->{object});
        die "no field id" unless ($params->{object_field_uuid});

        my $object = $params->{object} || die "no object";;
        unless (ref($object)) {
            my $object_id = $object;
            $object = new MinorImpact::Object($object_id) || die "can't create object '$object_id'";
        }
        my $field = $object->field($params->{object_field_uuid}) || die "no field";

        die "not a reference field" unless ($field->get('references'));

        die "no matching data" unless (_verifyObjectFieldData($object, $field, $data));

        $params->{name} = trunc(ptrunc($data, 1), 30);
    }
    my $self = $package->SUPER::_new($params);
    bless($self, $package);

    MinorImpact::log('debug', "ending");
    return $self;
}

=head2 addLink

=over

=item ->addLink($data)

=back

Applies the link in this reference to C<$data>;

=cut

sub addLink {
    my $self = shift || die "no reference";
    my $text = shift || return;

    my $new_text = $text;
    my $match = $self->match($text);
    if ($match) {
        my $url = MinorImpact::url({ action => 'object', object_id => $self->get('reference_object')->id()});
        $new_text =~s/$match/<a href='$url'>$match<\/a>/;
    }

    return $new_text;
}

our $VERSION = 4;
sub dbConfig {
    MinorImpact::log('debug', "starting");

    # Verify type exists.
    my $name = __PACKAGE__;
    my $type = MinorImpact::Object::Type::add({ name => $name, public=>0, no_tags => 1, no_name => 1, comments => 0, readonly => 1});
    die "Could not add object_type record\n" unless ($type);

    $type->addField({ name => 'data', required => 1, type => 'text', readonly => 1 });
    $type->addField({ name => 'object', type => 'object', required => 1, readonly => 1});
    $type->addField({ name => 'object_field_uuid', type => 'string', required => 1, readonly => 1});
    $type->addField({ name => 'reference_object', type => 'object', required => 1, readonly => 1});

    $type->setVersion($VERSION);
    $type->clearCache();

    MinorImpact::log('debug', "ending");
    return;
}

=head2 match

=over

=item ->match($text)

=back

Returns true if the reference object's C<data> matches C<$text>.

  $REFERENCE->update('data', "foo");
  $REFERENCE->match("This is foolhardy nonsense."); # returns TRUE

=cut

sub match {
    my $self = shift || die "no reference";
    my $value = shift || return;

    return _matchDataValue($self->get('data'), $value);
}

sub _matchDataValue {
    my $data = shift || return;
    my $value = shift || return;

    #$test_data =~s/\W/ /gm;
    #$test_data = join("\\W+?", split(/[\s\n]+/, $test_data));
    #if ($local_value->{value} =~/($test_data)/mgi) {
    #    my $match = $1;
    if ($value =~/($data)/) {
        return $1;
    }
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

sub objectField {
    my $self = shift || return;

    my $object = $self->get('object') || die "no object";
    my $field = $object->field($self->get('object_field_uuid')) || die "no field";

    return $field;
}

=head2 verify

=over

=item ->verify()

=back

Verify that the string in this reference is still part of the original object. Returns
1 if the reference is still good, 0 otherwise.

  # cleanup references after object update
  foreach $REFERENCE ($OBJECT->references()) {
    $REFERENCE->delete() unless ($REFERENCE->verify());
  }

=cut

sub verify {
    my $self = shift || return;

    my $object = $self->get('object') || return;
    my $field = $self->objectField() || return;
    my $data = $self->get('data') || return;
    $field->get('references') || return;

    return _verifyObjectFieldData($object, $field, $data);
}

sub _verifyObjectFieldData {
    my $object = shift || return;
    my $field = shift || return;
    my $data = shift || return;

    foreach my $value ($field->value()) {
        return 1 if (_matchDataValue($data, $value));
    }
    return;
}


=head1 AUTHOR

Patrick Gillan <pgillan@minorimpact.com>

=cut

1;
