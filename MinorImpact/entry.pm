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
            $params->{name} = substr($params->{detail}, 0, 15) ."-". int(rand(10000) + 1);
        }

        my @tags;
        if ($params->{detail}) {
            my $detail = $params->{detail};

            # Pullinline tags and convert them to object tags.
            $detail =~s/\r\n/\n/g;
            @tags = extractTags(\$detail);
            $detail = trim($detail);

            # Change links to markdown formatted links.
            foreach my $url ($detail =~/(?<![\[\(])(https?:\/\/[^\s]+)/) {
                my $md_url = "[$url]($url)";
                $detail =~s/(?<![\[\(])$url/$md_url/;
            }
            $params->{detail} = $detail;
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

our $VERSION = 4;
sub dbConfig {
    MinorImpact::log('debug', "starting");

    # Verify type exists.
    my $name = __PACKAGE__;
    my $type = MinorImpact::Object::Type::add({ name => $name, plural=>'entries', public=>1 });
    die "Could not add object_type record\n" unless ($type);

    $type->addField({ name => 'content', required => 1, type => 'text', });
    $type->addField({ name => 'publish_date', required => 1, type => 'datetime', });

    MinorImpact::addSetting({name => 'default_tag', type=>'string', default_value=>'new'});
    MinorImpact::addSetting({name => 'setting4', type=>'string', default_value=>'4', required=>1});

    $type->setVersion($VERSION);

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
