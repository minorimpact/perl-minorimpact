package MinorImpact::collection;

use MinorImpact;
use MinorImpact::Object;
use MinorImpact::Object::Type;
use MinorImpact::Util;

our @ISA = qw(MinorImpact::Object);

sub new {
    my $package = shift;
    my $params = shift;
    #MinorImpact::log('info', "starting");

    if (ref($params) eq 'HASH') {
        if ($params->{search}) {
            my $search = $params->{search};
            my @tags = extractTags(\$search);
            #MinorImpact::log('debug', "\@tags='" . join(",", @tags) . "'");
            $params->{text} = ($params->{text}?" ":"") . trim($search);
            $params->{tag} = ($params->{tag}?"\0":"") . join("\0", @tags);
        }
    }

    my $self = $package->SUPER::_new($params);
    bless($self, $package);

    #$self->log('info', "ending");
    return $self;
}

our $VERSION = 2;
sub dbConfig {
    #MinorImpact::log('info', "starting");

    # Verify type exists.
    my $name = __PACKAGE__;
    my $object_type_id = MinorImpact::Object::Type::add({
        name => $name, 
        readonly => 1,
        system => 0,
    });
    die "Could not add object_type record\n" unless ($object_type_id);

    MinorImpact::Object::Type::addField({
        object_type_id => $object_type_id,
        name => 'tag',
        type => '@string',
    });
    MinorImpact::Object::Type::addField({
        object_type_id => $object_type_id,
        name => 'text',
        type => '@string',
    });

    MinorImpact::Object::Type::setVersion($object_type_id, $VERSION);

    #MinorImpact::log('info', "ending");
    return;
}

sub searchParams {
    my $self = shift || return;

    #MinorImpact::log('info', "starting(" . $self->id() . ")");
    my $params = { debug => 'collection::searchParams();' }; 
    foreach my $tag ($self->get('tag')) {
        $params->{tag} .= "$tag,";
    }
    $params->{tag} =~s/[^\w]+$//;
    #MinorImpact::log('debug', "\$params->{tag}='" . $params->{tag} . "'");

    foreach my $text ($self->get('text')) {
        $params->{text} .= " $text";
    }
    trim($params->{text});

    #MinorImpact::log('debug', "\$params->{text}='" . $params->{text} . "'");
    
    #MinorImpact::log('info', "ending");
    return $params;
}

sub searchText {
    my $self = shift || return;
    my $params = shift || {};

    #MinorImpact::log('info', "starting(" . $self->id() . ")");
    my $text;
    foreach my $tag ($self->get('tag')) {
        $text .= "tag:$tag ";
    }

    foreach my $t ($self->get('text')) {
        $text .= "$t ";
    }
    
    #MinorImpact::log('info', "ending");
    return $text;
}

1;

