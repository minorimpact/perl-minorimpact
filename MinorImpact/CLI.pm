package MinorImpact::CLI;

use MinorImpact;
use Term::ReadKey;

=head1 NAME

MinorImpact::CLI - Command line library

=head1 SYNOPSIS

  use MinorImpact::CLI;

  $MINORIMPACT = new MinorImpact();

  $user = MinorImpact::CLI::login();

=head1 DESCRIPTION

=head1 SUBROUTINES

=cut

=head2 passwordPrompt

=over

=item passwordPrompt()

=item passwordPrompt(\%params)

=back

Prompt for a password.

=head3 Params

=over

=item confirm

If true, ask for the password twice to verify a match.
  $password = MinorImpact::CLI::passwordPromp({ username => 'foo' });
  # OUTPUT: Enter Password:
  # OUTPUT:          Again:

=item username

A username to supply for the prompt.

  $password = MinorImpact::CLI::passwordPromp({ username => 'foo' });
  # OUTPUT: Enter Password for 'foo':

=back

=cut

sub passwordPrompt {
    my $params = shift || {};

    print "Enter Password" . ($params->{username}?" for $params->{username}":"") . ": ";
    ReadMode('noecho');
    chomp(my $password = <STDIN>);
    print "\n";
    ReadMode(0);

    if ($params->{confirm}) {
        print "        Again: ";
        ReadMode('noecho');
        chomp(my $password2 = <STDIN>);
        print "\n";
        ReadMode(0);
        die "Passwords don't match\n" unless ($password eq $password2);
    }
    return $password;
}

=head1 AUTHOR

Patrick Gillan <pgillan@gmail.com>

=cut

1;
