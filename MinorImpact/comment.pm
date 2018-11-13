package MinorImpact::comment;

=head1 NAME

MinorImpact::comment

=head1 DESCRIPTION

A comment object for other MinorImpact objects.

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

    if (ref($params) eq "HASH") {
        MinorImpact::log('debug', "FUCK");
        # all comments are public.
        $params->{public} = 1;
        my $text = $params->{text};
        if (ref($text) eq 'ARRAY') {
            $text = @$text[0];
        }
        $params->{name} = trunc(ptrunc($text, 1), 30);
        MinorImpact::log('debug', "FUCK ALSO");
    }
    my $self = $package->SUPER::_new($params);
    bless($self, $package);

    MinorImpact::log('debug', "ending");
    return $self;
}

=head2 back

=over

=item ->back()

=back

Defaults to the object page for the entry this comment belongs to.

=cut

sub back {
    my $self = shift || return;

    my $object = $self->get('object');
    my $url = MinorImpact::url();
    if ($object && $object->typeID() != $self->typeID()) {
        $url = MinorImpact::url({ action => 'object', object_id => $object->id() });
    } elsif ($object) {
        $url = $object->back();
    }
   
    return $url;
}

=head2 cmp

Uses C<create_date> for sorting.

See L<MinorImpact::Object::cmp()|MinorImpact::Object/cmp>.

=cut

sub cmp {
    my $self = shift || return;
    my $b = shift;

    if ($b && ref($b)) {
        return ($self->get('create_date') cmp $b->cmp());
    }

    return $self->get('create_date');
}

our $VERSION = 2;
sub dbConfig {
    MinorImpact::log('debug', "starting");

    # Verify type exists.
    my $name = __PACKAGE__;
    my $type = MinorImpact::Object::Type::add({ name => $name, public=>0, no_tags => 1, no_name => 1, comments => 1});
    die "Could not add object_type record\n" unless ($type);

    $type->addField({ name => 'text', required => 1, type => 'text', });

    $type->addField({ name => 'object', type => 'object', required => 1, readonly => 1});

    $type->setVersion($VERSION);
    $type->clearCache();

    MinorImpact::log('debug', "ending");
    return;
}

sub entry {
    my $self = shift || die "no comment";

    return $self->get('entry');
}

=head2 toString

Overrides the C<list> format to use C<comment_list> instead of
C<object_list>.

See L<MinorImpact::Object::toString()|MinorImpact::Object/tostring>.

=cut

sub toString {
    my $self = shift || return;
    my $params = shift || {};

    MinorImpact::log('debug', "starting");

    my $local_params = clone($params);
    $local_params->{depth} = 0 unless ($local_params->{depth});;
    my $string;
    if ($local_params->{format} eq 'list') {
        $string = $self->SUPER::toString({template => 'comment_list', depth => $local_params->{depth}});
        $local_params->{depth}++;
        foreach my $comment ($self->children({object_type_id => $self->typeID() }))  {
            $string .= $comment->toString($local_params);
        }
    } elsif ($local_params->{format} eq 'row') {
        $string = "<tr><td>" . $self->type()->displayName() . "</td><td>" . $self->get('create_date') . "</td><td>" . $self->toString() . "</td></tr>\n";
    } else {
        $string = $self->SUPER::toString($local_params);
    }

    MinorImpact::log('debug', "ending");
    return $string;
}

=head1 AUTHOR

Patrick Gillan <pgillan@minorimpact.com>

=cut

1;
