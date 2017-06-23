#!/usr/bin/perl


use Data::Dumper;
use Term::ReadKey;
use Getopt::Long "HelpMessage";

use lib "/home/pgillan/www/project.minorimpact.com/lib";
use project;

use MinorImpact;
use MinorImpact::Object;
use MinorImpact::User;


my $MINORIMPACT;


my %options = (
                action => "list",
                config => "/home/pgillan/www/project.minorimpact.com/conf/minorimpact.conf",
                help => sub { HelpMessage(); },
                user => $ENV{USER},
            );

Getopt::Long::Configure("bundling");
GetOptions( \%options, 
            "action|a=s",
            "config|c=s", 
            "force|f",
            "help|?|h",
            "id|i=i",
            "password|p=s",
            "type_id|type|t=s",
            "user|u=s",
            "verbose",
        ) || HelpMessage();

eval { main(); };
if ($@) {
    HelpMessage({message=>$@, exitval=>1});
}


sub main {
    my $username = $ENV{USER};
    my $password = $options{password};
    if (!$password) {
        print "password: ";
        ReadMode('noecho');
        $password = <STDIN>;
        chomp($password);
        print "\n";
        ReadMode('restore');
    }
    $MINORIMPACT = new MinorImpact({config_file=>$options{config}});
    my $user = $MINORIMPACT->getUser({username=>$username, password=>$password}) || die "Unable to validate user";

    if ($options{id} && (!$options{action} || $options{action} eq 'list')) {
        # We can't 'list' a single object, so just change it to 'info' if ID is defined.
        $options{action} = 'info';
    }

    if ($options{action} eq 'list') {
        my $params;
        $params->{user_id} = $user->id();
        $params->{object_type_id} = $options{type_id};
        my @objects = MinorImpact::Object::search($params);
        foreach my $object (@objects) {
            printf("%s (%d)\n", $object->name(), $object->id());
        }
    } elsif ($options{id} && $options{action} eq 'info') {
        my $object = new MinorImpact::Object($options{id}, {user_id=>$user->id()}) || die "Can't retrieve object.";
        print $object->name() . " (" . $object->id() . ")\n";
        print "-------\n";
        print "  type: " . $object->typeName() . "\n";
        print "  description:" . $object->get('description') . "\n";
        print  "  fields:\n";
        my $fields = $object->fields();
        foreach my $field_name (sort keys %$fields) {
            my $field = $fields->{$field_name};
            print "    $field_name: " . join(",", $field->value()) . "\n";
        }

        print "\n";
    } else {
         HelpMessage({message=>"No valid ACTION specified.", exitval=>0});
     }
}

=pod

=head1 NAME

object.pl - Command line tool for viewing and editing MinorImpact object databases.

=head1 SYNOPSIS

object.pl [options]

  Options:
  -a, --action=ACTION   Perform ACTION.  default: info
                        Actions:
                            info    Show information about ID.
                            list    show all objects that match search criteria. See "List options" below.
  -c, --config=FILE     Read connection information from FILE.
  -f, --force           Never request conformation.
  -h, --help            Usage information.
  -i, --id=ID           ID of the object you want to take action on.
  -p, --password=PASSWORD
                        Connect with PASSWORD.  Will prompt if not specified.
  -u, --user=USER       Connect as USER.  default: $ENV{USER}
  -v, --verbose         Verbose output.

  List options:
  -t, --type_id=TYPE    Object is TYPE.

=cut

