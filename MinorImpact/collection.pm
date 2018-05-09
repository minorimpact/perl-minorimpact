package MinorImpact::collection;

use Data::Dumper;
use Storable qw(nfreeze thaw);
use MIME::Base64;

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
        # Stop trying this.  All the logic for translating or parsing the object
        #   data is in the update() and get() subs.  So why is {search} doing its thing
        #   up there? Because search is a convenience value, and not actually a part of
        #   the object, so it's really just getting broken up into {text} and {tag}, two
        #   parameters that *are* part of the official object.  This could also be moved
        #   to update(), and I might do that later if it makes sense.
        #if ($params->{search_filter}) {
        #    $params->{search_filter} = freeze($params->{search_filter});
        #}
    }

    my $self = $package->SUPER::_new($params);
    bless($self, $package);

    #$self->log('info', "ending");
    return $self;
}

our $VERSION = 3;
sub dbConfig {
    #MinorImpact::log('info', "starting");

    # Verify type exists.
    my $name = __PACKAGE__;
    my $object_type_id = MinorImpact::Object::Type::add({ name => $name, readonly => 1, system => 0, });
    die "Could not add object_type record\n" unless ($object_type_id);

    MinorImpact::Object::Type::addField({ object_type_id => $object_type_id, name => 'tag', type => '@string', });
    MinorImpact::Object::Type::addField({ object_type_id => $object_type_id, name => 'text', type => '@string', });
    MinorImpact::Object::Type::addField({ object_type_id => $object_type_id, name => 'search_filter', type => 'text', });

    MinorImpact::Object::Type::setVersion($object_type_id, $VERSION);

    #MinorImpact::log('info', "ending");
    return;
}

sub get {
    my $self = shift || return;
    my $name = shift || return;
    my $params = shift || {};

    MinorImpact::log('debug', "starting($object_id)");
    my @values = $self->SUPER::get($name, $params);
    MinorImpact::log('debug', "$name='$value'");
    if ($name eq 'search_filter') {
        my $v = {};
        if ($values[0]) {
            $v = thaw(decode_base64($values[0]));
        }
        push(@values, $v);
    } 
    MinorImpact::log('debug', "ending($object_id)");
    return @values;
}

# Return an object suitable for use as a 'query' parameter for MinorImpact::Object::Search::search().
sub searchParams {
    my $self = shift || return;

    #MinorImpact::debug(1);
    MinorImpact::log('debug', "starting(" . $self->id() . ")");
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

    foreach my $search_filter ($self->get('search_filter')) {
        foreach my $t (keys %$search_filter) {
            MinorImpact::log('debug', "$t = '" . $search_filter->{$t} . "'");
            $params->{$t} = $search_filter->{$t};
        }
    }

    #MinorImpact::log('debug', "\$params->{text}='" . $params->{text} . "'");
    
    MinorImpact::log('debug', "ending");
    #MinorImpact::debug(0);
    return $params;
}

# Return a string that MinorImpact::Object::Search::search() can parse 
#   to generate a 'query' parameter for itself.
sub searchText {
    my $self = shift || return;
    my $params = shift || {};

    #MinorImpact::log('info', "starting(" . $self->id() . ")");
    my $text;
    foreach my $tag ($self->get('tag')) {
        $text .= "tag:$tag ";
    }
    my $search_filter = $self->get('search_filter');
    foreach my $t (keys %$search_filter) {
        $text .= "$t:" . $search_filter->{$t} . " ";
    }

    foreach my $t ($self->get('text')) {
        $text .= "$t ";
    }
    
    #MinorImpact::log('info', "ending");
    return $text;
}

sub update {
    my $self = shift || return;
    my $params = shift || {};

    my $local_params = cloneHash($params);
    if ($local_params->{search_filter}) {
        $local_params->{search_filter} = encode_base64(nfreeze($local_params->{search_filter}));
    }
    #MinorImpact::debug(1);
    $self->SUPER::update($local_params);
    #MinorImpact::debug(0);
}

1;
