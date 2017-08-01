package collection;

use MinorImpact;
use MinorImpact::Object;
use MinorImpact::Util;

our @ISA = qw(MinorImpact::Object);

sub new {
    my $package = shift;
    my $params = shift;
    #MinorImpact::log(7, "starting");

    if (ref($params) eq 'HASH') {
        if ($params->{search}) {
            my $search = $params->{search};
            my @tags = extractTags(\$search);
            #MinorImpact::log(8, "\@tags='" . join(",", @tags) . "'");
            $params->{text} = ($params->{text}?" ":"") . trim($search);
            $params->{tag} = ($params->{tag}?"\0":"") . join("\0", @tags);
        }
    }

    my $self = $package->SUPER::_new($params);
    bless($self, $package);

    #$self->log(7, "ending");
    return $self;
}

sub searchParams {
    my $self = shift || return;

    #MinorImpact::log(7, "starting(" . $self->id() . ")");
    my $params = { debug => 'collection::searchParams();' }; 
    foreach my $tag ($self->get('tag')) {
        $params->{tag} .= "$tag,";
    }
    $params->{tag} =~s/[^\w]+$//;
    #MinorImpact::log(8, "\$params->{tag}='" . $params->{tag} . "'");

    foreach my $text ($self->get('text')) {
        $params->{text} .= " $text";
    }
    trim($params->{text});

    #MinorImpact::log(8, "\$params->{text}='" . $params->{text} . "'");
    
    #MinorImpact::log(7, "ending");
    return $params;
}

sub searchText {
    my $self = shift || return;
    my $params = shift || {};

    #MinorImpact::log(7, "starting(" . $self->id() . ")");
    my $text;
    foreach my $tag ($self->get('tag')) {
        $text .= "tag:$tag ";
    }

    foreach my $t ($self->get('text')) {
        $text .= "$t ";
    }
    
    #MinorImpact::log(7, "ending");
    return $text;
}

1;

