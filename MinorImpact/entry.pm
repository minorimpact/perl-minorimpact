package MinorImpact::entry;

use strict;

use Time::Local;

use MinorImpact::Object;
use MinorImpact::Util;

our @ISA = qw(MinorImpact::Object);

sub new {
    my $package = shift;
    my $params = shift;
    MinorImpact::log('debug', "starting");

    if (ref($params) eq "HASH") {
        if (!$params->{name}) {
            $params->{name} = trunc($params->{content}, 0, 15) ."-". int(rand(10000) + 1);
        }

        my @tags;
        if ($params->{content}) {
            my $content = $params->{content};

            # Pullinline tags and convert them to object tags.
            $content =~s/\r\n/\n/g;
            @tags = extractTags(\$content);
            $content = trim($content);

            # Change links to markdown formatted links.
            foreach my $url ($content =~/(?<![\[\(])(https?:\/\/[^\s]+)/) {
                my $md_url = "[$url]($url)";
                $content =~s/(?<![\[\(])$url/$md_url/;
            }
            $params->{content} = $content;
        }

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

sub cmp {
    my $self = shift || return;
    my $b = shift;

    if ($b && ref($b)) {
        return ($self->get('publish_date') cmp $b->cmp());
    }

    return $self->get('publish_date');
}

our $VERSION = 15;
sub dbConfig {
    MinorImpact::log('debug', "starting");

    # Verify type exists.
    my $name = __PACKAGE__;
    my $type = MinorImpact::Object::Type::add({ name => $name, plural=>'entries', public=>1 });
    die "Could not add object_type record\n" unless ($type);

    $type->addField({ name => 'content', required => 1, type => 'text', });
    $type->addField({ name => 'publish_date', required => 1, type => 'datetime', });

    MinorImpact::addSetting({name => 'default_tag', type=>'string', default_value=>'' });

    $type->setVersion($VERSION);
    $type->clearCache();

    MinorImpact::log('debug', "ending");
    return;
}

sub toString {
    my $self = shift || return;
    my $params = shift || {};

    MinorImpact::log('debug', "starting");

    MinorImpact::log('debug', "\$params='$params'");
    my $string;
    if ($params->{format} eq 'list') {
        $string = $self->SUPER::toString({template => 'entry_list'});
    } elsif ($params->{format} eq 'row') {
        $string = "<tr><td>" . $self->get('publish_date') . "</td><td>" . $self->toString() . "</td></tr>\n";
    } else {
        $string = $self->SUPER::toString($params);
    }

    MinorImpact::log('debug', "ending");
    return $string;
}
1;
