package MinorImpact::Object::Field::url;

use MinorImpact;
use MinorImpact::Object::Field;

our @ISA = qw(MinorImpact::Object::Field);

sub new {
    my $package = shift || return;
    my $data = shift || return;

    #MinorImpact::log(7, "starting");

    my $local_data = cloneHash($data);
    $local_data->{attributes}{maxlength} = 2048;
    $local_data->{attributes}{is_text} = 1;

    my $self = $package->SUPER::_new($local_data);
    bless($self, $package);
    #MinorImpact::log(7, "ending");
    return $self;
}

sub toString {
    my $self = shift || return;
    #MinorImpact::log(7, "starting");

    my $string;
    foreach my $value ($self->value()) {
        $string .= "<a href=$value>$value</a>,";
    }
    $string =~s/,$//;
    #MinorImpact::log(7, "ending");
    return $string;
}

1;
