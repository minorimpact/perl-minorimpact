package MinorImpact::Test;

use Data::Dumper;
@EXPORT = ( 
    "randomUser", 
);

sub randomUser {
    my $MI = new MinorImpact();
    my $USERDB = $MI->{USERDB};
    my $username = $USERDB->selectrow_array("SELECT name FROM user WHERE name LIKE 'test_user_%' ORDER BY RAND() LIMIT 1") || die $USERDB->errstr;
    if ($username) {
        my ($password) = $username =~/_([0-9]+)$/;
        return MinorImpact::getUser({ username => $username, password => $password });
    }
}

1;

