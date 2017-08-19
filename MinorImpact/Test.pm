package MinorImpact::Test;

use strict;

use Data::Dumper;

use MinorImpact::Object;
use MinorImpact::Util;

our @EXPORT = ( 
    "randomUser", 
    "tag",
);

sub randomUser {
    my $MI = new MinorImpact();
    my $USERDB = $MI->{USERDB};
    my $username = $USERDB->selectrow_array("SELECT name FROM user WHERE name LIKE 'test_user_%' ORDER BY RAND() LIMIT 1") || die $USERDB->errstr;
    if ($username) {
        my ($password) = $username =~/_([0-9]+)$/;
        return MinorImpact::user({ username => $username, password => $password });
    }
}

sub tag {
    my @user_tags = @_;

    my $tag_count = int(rand(4)) + 1;
    my @all_tags = MinorImpact::Object::tags();

    my $tags;
    for (my $i = 0; $i<$tag_count; $i++) {
        my $tag_type = int(rand(100));
        my $tag;
        if ($tag_type < 5 || scalar(@all_tags) == 0 ) {
            $tag = randomText(1);
        } elsif ($tag_type < 75 || scalar(@user_tags) == 0 ) {
            $tag = $all_tags[int(rand(scalar(@all_tags)))];
        } else {
            $tag = $user_tags[int(rand(scalar(@user_tags)))];
        }
        $tags .= "$tag,";
    }
    $tags =~s/,$//;
    return $tags;
}

1;

