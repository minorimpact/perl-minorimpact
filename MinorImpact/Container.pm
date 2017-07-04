package MinorImpact::Container;

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

    my $params = {debug=>"MinorImpact::Container::searchParams();"};
    foreach my $tag ($self->get('tag')) {
        $params->{tag} .= "$tag,";
    }
    $params->{tag} =~s/[, ]*$//;
    $params->{text} = $self->get('text');

    return $params;
}


1;

