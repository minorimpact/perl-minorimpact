package MinorImpact::entry;

=head1 NAME

MinorImpact::entry - A 'blog entry' object.

=head1 SYNOPSIS

  use MinorImpact;

  $entry = new MinorImpact::entry({ 
    name => 'Tuesday', 
    content => "I've never quite gotten the hang of Tuesdays.",
    publish_date => "1992-04-06"m
    public => 1,
  });

=head1 DESCRIPTION

Part of the default/example MinorImpact application, this is a very simple "blog entry" object
inherited from L<MinorImpact::Object>.

=cut

use strict;

use Time::Local;

use MinorImpact::comment;
use MinorImpact::Object;
use MinorImpact::Util;
use MinorImpact::Util::String;

our @ISA = qw(MinorImpact::Object);

=head1 METHODS

=cut

sub new {
    my $package = shift;
    my $params = shift;
    MinorImpact::log('debug', "starting");

    if (ref($params) eq "HASH") {
        if (!$params->{name}) {
            $params->{name} = trunc($params->{content}, 0, 30);
        }

        my @tags;
        #if ($params->{content}) {
        #    my $content = $params->{content};
        #
        #    # Pullinline tags and convert them to object tags.
        #    $content =~s/\r\n/\n/g;
        #    @tags = extractTags(\$content);
        #    $content = trim($content);
        #
        #    # Change links to markdown formatted links.
        #    foreach my $url ($content =~/(?<![\[\(])(https?:\/\/[^\s]+)/) {
        #        my $md_url = "[$url]($url)";
        #        $content =~s/(?<![\[\(])$url/$md_url/;
        #    }
        #    $params->{content} = $content;
        #}

        my $user = MinorImpact::user({ force => 1 });
        my $settings = $user->settings();
        $params->{tags} .= " " . join(" ", @tags) . " " . $settings->get('default_tag');
        #MinorImpact::log(8, "\$params->{tags}='" . $params->{tags} . "'");
    }
    my $self = $package->SUPER::_new($params);
    bless($self, $package);

    MinorImpact::log('debug', "ending");
    return $self;
}

=head2 cmp

Overrides the default and Uses 'publish_date' for sorting.

=cut

sub cmp {
    my $self = shift || return;
    my $b = shift;

    if ($b && ref($b)) {
        return ($self->get('publish_date') cmp $b->cmp());
    }

    return $self->get('publish_date');
}

sub children {
    my $self = shift || die "No self";
    my $params = shift || {};
    MinorImpact::log('debug', "starting");


    my $local_params = clone($params);
    $local_params->{query} = {} unless (defined($local_params->{query}));
    $local_params->{query}{object_type_id} = "MinorImpact::comment";

    my @comments = $self->SUPER::children($local_params);

    MinorImpact::log('debug', "ending");
    return @comments;
}

our $VERSION = 26;
sub dbConfig {
    MinorImpact::log('debug', "starting");

    # Verify type exists.
    my $name = __PACKAGE__;
    my $type = MinorImpact::Object::Type::add({ name => $name, plural=>'entries', comments => 1, public=>1 });
    die "Could not add object_type record\n" unless ($type);

    $type->addField({ name => 'content', required => 1, type => 'text', });
    $type->addField({ name => 'publish_date', required => 1, type => 'datetime', sort => 1 });

    MinorImpact::addSetting({name => 'default_tag', type=>'string', default_value=>'' });

    $type->setVersion($VERSION);
    $type->clearCache();

    MinorImpact::log('debug', "ending");
    return;
}


=head2 get

Overrides the 'public' value to also check whether or not 'publish_date' has
passed.

=cut

sub get {
    my $self = shift || return;
    my $name = shift || return;
    my $params = shift || {};

    MinorImpact::log('debug', "starting(" . $name . ")");

    my $value;
    if ($name eq 'public') {
        if ($self->SUPER::get('public') && fromMysqlDate($self->get('publish_date')) < time()) {
            $value = 1;
        } else {
            $value = 0;
        }
    } else {
        $value = $self->SUPER::get($name, $params);
    }

    MinorImpact::log('debug', "ending($value)");
    return $value;
}

=head2 toString

Overrides 'page' and 'list' with custom templates.

=cut

sub toString {
    my $self = shift || return;
    my $params = shift || {};

    MinorImpact::log('debug', "starting");

    MinorImpact::log('debug', "\$params='$params'");
    my $string;
    if ($params->{format} eq 'page') {
        $string = $self->SUPER::toString({template => 'entry_page'});
    } elsif ($params->{format} eq 'list') {
        $string = $self->SUPER::toString({template => 'entry_list'});
    } elsif ($params->{format} eq 'row') {
        $string = "<tr><td>" . $self->type()->displayName() . "</td><td>" . $self->get('publish_date') . "</td><td>" . $self->toString() . "</td></tr>\n";
    } else {
        $string = $self->SUPER::toString($params);
    }

    MinorImpact::log('debug', "ending");
    return $string;
}

=head1 AUTHOR

Patrick Gillan <pgillan@minorimpact.com>

=cut

1;
