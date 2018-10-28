package MinorImpact::settings;

use MinorImpact;
use MinorImpact::Object;
use MinorImpact::Object::Type;
use MinorImpact::Util;

=head1 NAME

MinorImpact::settings - Site settings.

=cut

=head1 SYNOPSIS

=cut

=head1 DESCRIPTION

=cut

our @ISA = qw(MinorImpact::Object);

sub new {
    my $package = shift;
    my $params = shift;
    MinorImpact::log('debug', "starting");

    my $self = $package->SUPER::_new($params);
    bless($self, $package);

    MinorImpact::log('debug', "ending");
    return $self;
}

our $VERSION = 10;
sub dbConfig {
    MinorImpact::log('debug', "starting");

    # Verify type exists.
    my $name = __PACKAGE__;
    my $type = MinorImpact::Object::Type::add({ name => $name, plural => "settings", readonly => 1, system => 1, no_name => 1, no_tags => 1 });
    die "Could not add object_type record\n" unless ($type);

    $type->addField({name => 'results_per_page', default_value => 20, type=>'int', required => 1});
    $type->deleteField({name => 'test7', default_value => 7, type=>'string', required => 1});
    $type->deleteField({name => 'test8', default_value => 8, type=>'string', required => 1});
    $type->deleteField({name => 'test9', default_value => 9, type=>'string', required => 1});

    $type->setVersion($VERSION);

    MinorImpact::log('debug', "ending");
    return;
}

1;
