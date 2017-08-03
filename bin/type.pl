#!/usr/bin/perl

use strict;

use Data::Dumper;
use Term::ReadKey;
use Getopt::Long "HelpMessage";

use MinorImpact;
use MinorImpact::Object;
use MinorImpact::Object::Type;

my $MINORIMPACT;

my %options = (
                action => "list",
                # TODO: Get rid of this, it should either be passed on the comman line,
                #   or read from a standard place, /etc/minorimpact.conf
                config => "/home/pgillan/www/project.minorimpact.com/conf/minorimpact.conf",
                help => sub { HelpMessage(); },
                user => $ENV{USER},
            );

Getopt::Long::Configure("bundling");
GetOptions( \%options, 
            "action|a=s",
            "addfield",
            "config|c=s", 
            "field-name=s",
            "field-description=s",
            "field-type=s",
            "field-hidden",
            "field-required",
            "field-readonly",
            "field-sortby",
            "force|f",
            "help|?|h",
            "module|m=s",
            "password|p=s",
            "plural=s",
            "system",
            "type|type_id|t=s",
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
    my $user = $MINORIMPACT->user({username=>$username, password=>$password}) || die "Unable to validate user";
    die $user->name() . " does not have admin priviledges" unless ($user->isAdmin());
    my $DB = $MINORIMPACT->db();
    MinorImpact::checkDatabaseTables($DB);


    # Just change the action from list to info if someone specifies a type - ou
    #   can't list a single item.
    $options{action} = "addfield" if ($options{addfield} && !$options{action});
    if ($options{type} && $options{action} eq 'list') {
        $options{action} = 'info';
    }
    if ($options{action} eq 'list') {
        my $types = MinorImpact::Object::types() || die "Can't retrieve list of types.\n";
        foreach my $type (sort {$a->{name} cmp $b->{name}; } @$types) {
            print "$type->{name} ($type->{id})\n";
            print "--------\n";
            print "  plural: " . ($type->{plural}?$type->{plural}:$type->{name}."s") . "\n";
            print "\n";
        }
    } elsif ($options{action} eq 'addfield') {
        my $type_id = MinorImpact::Object::typeID($options{type}) || die "Can't get id for $options{type}";

        my $params;
        $params->{object_type_id} = $type_id;
        $params->{name} = $options{"field-name"};
        $params->{description} = $options{"field-description"};

        # We store fields that are references to other object as type object[<object id>].  This ia 
        #   convenience to allow people to reference it by the type name instead of the id.
        my $type = $options{"field-type"};
        $type =~s/^@//;
        my $type_id = MinorImpact::Object::typeID($type);
        if ($type_id) {
            $params->{type} = "object[$type_id]";
            $params->{type} = "@" . $params->{type} if ($options{"field-type"} =~/^@/);
        } else {
            $params->{type} = $options{"field-type"};
        }

        $params->{hidden} = $options{"field-hidden"};
        $params->{required} = $options{"field-required"};
        $params->{readonly} = $options{"field-readonly"};
        $params->{sortby} = $options{"field-sortby"};
        MinorImpact::Object::Field::addField($params);
    } elsif ($options{action} eq 'addtype') {
        my $type = $options{type};
        my $type_id = MinorImpact::Object::typeID($type);
        die "$type already exists." if ($type_id);


        my $name = $options{type};
        my $plural = $options{plural} ||"${name}s";
        my $system = ($options{system}?1:0);

        $DB->do("INSERT INTO object_type (name, system, plural, create_date) VALUES (?, ?, ?, NOW())", undef, ($name, $system, $plural)) || die $DB->errstr;

    } elsif ($options{action} eq 'bootstrap') {
        my $module = $options{module};
        my ($short_name) = $module =~/\/([^.\/]+)\.pm$/;
        print "$short_name\n";
        die "invalid module: $module" unless ($module && $short_name && -f $module);
        eval {
            require $module;
            $short_name->dbConfig();
        };
        die $@ if ($@);
    } elsif ($options{action} eq 'delfield') {
        my $type_id = MinorImpact::Object::typeID($options{type}) || die "Can't get id for $options{type}";
        my $type_name = MinorImpact::Object::typeName($type_id);

        my $params;
        $params->{object_type_id} = $type_id;
        $params->{name} = $options{"field-name"};

        if (!$options{force}) {
            print "This will also erase all the data in this field from all objects, and CANNOT BE UNDONE! Are you sure you want to delete the $options{'field-name'} field from the $type_name object? (y/N) ";
            my $input = <STDIN>;
            chomp($input); $input = (split(//, $input))[0];
            if ($input !~/^[yY]$/) {
                exit;
            }
        }
        print "Deleting $options{'field-name'} from $type_name\n";
        MinorImpact::Object::Field::delField($params);
    } elsif ($options{type} && $options{action} eq 'info') {
        my $type_id = MinorImpact::Object::typeID($options{type}) || die "Can't get id for $options{type}";
        my ($type_name, $plural_type_name) = MinorImpact::Object::typeName({object_type_id=>$type_id});
        my $fields = MinorImpact::Object::fields({object_type_id=>$type_id});

        print "$type_name ($type_id)\n";
        print "----------\n";
        print "  info:\n";
        print "    plural: $plural_type_name\n";
        print "  fields:\n";
        foreach my $field_name (sort keys %$fields) {
            my $field = $fields->{$field_name};
            print "    " . $field->name() . "\n";
            print "      " . $field->get('description') . "\n" if ($field->get('description'));
            my $type_name = $field->type();
            if ($type_name =~/object\[(\d+)\]$/) {
                $type_name = MinorImpact::Object::typeName($1);
                $type_name = "@" . $type_name if ($field->type() =~/^@/);
            }
            print "      type: $type_name\n";
            print "      display name: " . $field->displayName() . "\n";
        }
        print "\n";
    } else {
        HelpMessage({message=>"No valid ACTION found.", exitval=>0});
    }
}

=pod

=head1 NAME

type.pl - Command line tool for viewing and editing MinorImpact object types.

=head1 SYNOPSIS

type.pl [options]

  Options:
  -a, --action=ACTION   Perform ACTION.  default: list
                        Actions:
                            addtype     Create a new TYPE.
                            addfield    Add a new field FIELDNAME to TYPE. See "Field options" below.
                            delfield    Delete field FIELDNAME from TYPE.
                            info        Show information about TYPE.
                            list        show all types.
      --addfield        Equivilant to --action=addfield.
  -c, --config=FILE     Read connection information from FILE.
  -f, --force           Never request conformation.
  -h, --help            Usage information.
  -p, --password=PASSWORD
                        Connect with PASSWORD.  Will prompt if not specified.
      --system          TYPE will considered a 'system' object.
  -t, --type=TYPE       Work with TYPE object definition.
  -u, --user=USER       Connect as USER.  default: $ENV{USER}
  -v, --verbose         Verbose output.

  Type options:
      --plural          The plural form of TYPE.

  Field options:
      --field-name=FIELDNAME
                        Field name.
      --field-description=DESCRIPTIOn
                        Field description.
      --field-type=FIELDTYPE
                        Field type.

    The following options are true/false:
      --field-hidden    field will show up on forms.
      --field-required  field is required.
      --field-readonly  field is viewable, but not user editable.
      --field-sortby    When sorting lists, use this field.

=cut

