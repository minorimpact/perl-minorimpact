package MinorImpact::Object::Field::url;

use MinorImpact;
use MinorImpact::Util;
use MinorImpact::Object::Field;

our @ISA = qw(MinorImpact::Object::Field);

sub new {
    my $package = shift || return;
    my $data = shift || return;

    #MinorImpact::log('info', "starting");

    $data->{attributes}{maxlength} = 2048;
    $data->{attributes}{is_text} = 1;

    my $self = $package->SUPER::_new($data);
    bless($self, $package);
    #MinorImpact::log('info', "ending");
    return $self;
}

sub toString {
    my $self = shift || return;
    #MinorImpact::log('info', "starting");

    my $string;
    foreach my $value ($self->value()) {
        $string .= "<a href=$value>$value</a>,";
    }
    $string =~s/,$//;
    #MinorImpact::log('info', "ending");
    return $string;
}

1;
