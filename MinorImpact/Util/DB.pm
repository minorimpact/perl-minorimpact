package MinorImpact::Util::DB;

=head1 NAME

MinorImpact::Util::DB - MinorImpact database utilities

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 METHODS

=cut

use Data::Dumper;
use MinorImpact::Util;

=head2 addTable

=over

=item ::addTable($dbh, \%params)

=back

A table definition to create, or edit if it already exists.

  MinorImpact::Util::DB::addTable($dbh, {
    name => 'test', 
    fields => {
      int_field => { type => 'int' }
    }
  });

=head3 params

=over

=item fields => { $name => \%hash[, ... ] }

A hash of hashes, one for each field, where the key 
is the field name.  Required.

  MinorImpact::Util::DB::addTable($dbh, {
    name => 'test', 
    fields => { 
      int_field => { type => 'int', default => 0 },
      string_field => { type => 'varchhar(50)', null => 0 }
    }
  });

Each field can have the follow attributes.

=over

=item default => $string

Set $string to be the default value for the field.

=item null => TRUE/FALSE

If FALSE, the field will set to not allow NULL values. Default: TRUE

=item primary_key => TRUE/FALSEa

Thil field should be set as primary key.

=item type => $string

Field type.  Required.

=back

=item indexes => { $name => \%hash[, ...] }

Create a set of indexes called $name with the following attributes.

  MinorImpact::Util::DB::addTable({
    name => 'test', 
    fields => { 
      int_field => { type => 'int', default => 0 },
      string_field => { type => 'varchhar(50)', null => 0 }
    },
    indexes => {
      idx_test_int => { fields => "int_field" },
      idx_all_fields => { fields => "int_field,string_field" },
  });

=over

=item fields => $string

A comma separated list of fields this index should be applied to. Required.

=item unique => TRUE/FALSE

This is a unique index.

=back

=item name

Table name.  Required.

=back

=cut

our $SUBS = {};
sub addTable {
    my $DB = shift || die "no db";
    my $params = shift || die "no params";

    my $table_name = $params->{name} || die "no table name";
    my $fields = $params->{fields} || die "no fields";

    # 'null' means nulls are allowed for the field, and it's a fucking pain in the ass
    #   having "undefined" meaning true, so I'm just setting them all
    #   to 1 if they're not defined.
    foreach my $field_name (keys %$fields) {
        my $field = $fields->{$field_name};
        $field->{null} = 1 unless (defined($field->{null}));
    }

    # Sort the index fields, it's just easier later.
    map { $_->{fields} = join(',', sort split(/,/, $_->{fields})); }  %{$params->{indexes}};

    _setDriverSubs($DB);
    my $db_name = _dbName($DB);
    my @db_tables = $DB->tables();
    if (grep { /^`$db_name`\.`$table_name`$/ } @db_tables) {
        $SUBS->{updateTable}($DB, $params);
    } else {
        $SUBS->{createTable}($DB, $params);
    }
}

=head2 _dbName

=over

=item _dbName($dbh)

=back

Parsed the database name from $dbh->{Name}.

  $db_name = _dbName($dbh);

=cut 

sub _dbName {
    my $DB = shift || die "no db";

    my ($db_name) = $DB->{Name} =~/database=([^;]+);/;

    return $db_name;
}

sub createTableMySQL {
    my $DB = shift || die "no db";
    my $params = shift || die "no params";

    my $table_name = $params->{name} || die "no table name";
    my $fields = $params->{fields} || die "no fields";
    my $indexes = $params->{indexes} || [];

    my $sql = "CREATE TABLE `$table_name` (\n";
    my $primary_key;
    foreach my $field_name (keys %$fields) {
        my $field = $fields->{$field_name};

        my $field_sql = $SUBS->{field}->($field_name, $field);
        $primary_key = "$field_name" if (defined($field->{primary_key}) && isTrue($field->{primary_key}));

        $sql .= "  $field_sql,\n";
    }
    $sql .= "  PRIMARY KEY (`$primary_key`),\n" if ($primary_key);
    $sql =~s/,\n$/\n/;
    $sql .= ")";

    #print "$sql\n";
    $DB->do($sql) || die $DB->errstr;

    foreach my $index_name (keys %$indexes) {
        next if ($index_name eq 'PRIMARY');
        my $index = $indexes->{$index_name};
        my $fields = $index->{fields} || die "no fields specified for index";

        my $sql = "CREATE " . ($index->{unique}?"UNIQUE":"") . " INDEX `$index_name` ON $table_name($fields)";
        #print "$sql\n";
        $DB->do($sql) || die $DB->errstr;
    }
    return;
}

sub deleteTable {
    my $DB = shift || die "no db";
    my $table_name = shift || die "no table name";

    _setDriverSubs($DB);
    return $SUBS->{dropTable}->($DB, $table_name);
}

sub dropTableMySQL {
    my $DB = shift || die "no db";
    my $table_name = shift || die "no table name";

    $DB->do("DROP TABLE $table_name") || die $DB->errstr;
    return;
}

sub indexMySQL {
    my $DB = shift || die "no db";
    my $table_name = shift || die "no table name";

    my $indexes = {};

    my $data = $DB->selectall_arrayref("SHOW INDEX FROM $table_name", { Slice => {} });
    foreach my $row (@$data) {
        my $index_name = $row->{Key_name};
        my $column_name = $row->{Column_name};
        $indexes->{$index_name}->{fields} .= "$column_name,";
    }

    map { $_->{fields} =~s/,$//; } %$indexes;
    map { $_->{fields} = join(',', sort split(/,/, $_->{fields})); }  %$indexes;

    return $indexes;
}

=head2 _indexName

=over

=item _indexName($table_name, $fields);

=back

Returns a string built from the $table_name and the comma
separate list of $fields being indexed.

  $index_name = _indexName($table_name, $fields);

=cut

sub _indexName {
    my $table_name = shift || return;
    my $fields = shift || return;

    my $index_name = $fields;
    $index_name =~s/[ ,]+/_/g;
    $index_name = "idx_{$table_name}_$index_name";
    return $index_name;
}

sub fieldMySQL {
    my $field_name = shift || die "no field name";
    my $field = shift || die "no field";

    my $sql = '';

    my $field_type = $field->{type} || die "no field type for '$field_name'";
    $field_type = $SUBS->{type}->($field_type);

    my $auto_increment = "AUTO_INCREMENT" if (defined($field->{auto_increment}) && isTrue($field->{auto_increment}));
    my $default = (defined($field->{default}))?"DEFAULT '" . $field->{default} . "'":'';
    my $null = (defined($field->{null}) && !isTrue($field->{null}))?'NOT NULL':'';

    $sql = "`$field_name` $field_type $null $default $auto_increment";

    trim(\$sql);
    return $sql;
}

sub _setDriverSubs {
    my $DB = shift || die "no db";

    my $driver = $DB->get_info(17) || die "no database driver name";

    if ($driver eq "MySQL") {
        $SUBS = {
            createTable => \&createTableMySQL,
            dropTable => \&dropTableMySQL,
            field => \&fieldMySQL,
            index => \&indexMySQL,
            type => \&typeMySQL,
            updateTable => \&updateTableMySQL,
        };
    } else {
        die "unsupported driver: $driver";
    }
}

sub typeMySQL {
    my $field_type = shift || die "no type specified";

    my %FIELD_TYPE_CONVERT = ( 
        boolean => "tinyint(1)",
        int => "int(11)",
    );

    my $MySQL_field_type = $FIELD_TYPE_CONVERT{$field_type} || $field_type;
    return $MySQL_field_type;
}

sub updateTableMySQL {
    my $DB = shift || die "no db";
    my $params = shift || die "no params";

    #print "update table\n";

    my $db_name = _dbName($DB);
    my $table_name = $params->{name} || die "no table name";
    my $fields = $params->{fields} || die "no fields";
    my $indexes = $params->{indexes} || {};

    my $sth = $DB->column_info(undef, $db_name, $table_name, '%');
    my $db_columns = $sth->fetchall_hashref('COLUMN_NAME');
    #print Dumper($db_columns);

    foreach my $field_name (keys %$fields) {
        my $field = $fields->{$field_name};
        if  ($db_columns->{$field_name}) {
            # edit field in DB
            if (( $field->{type} ne 'timestamp' && $db_columns->{$field_name}{COLUMN_DEF} ne $field->{default}) ||
                $db_columns->{$field_name}{mysql_is_auto_increment} ne isTrue($field->{auto_increment}) ||
                $db_columns->{$field_name}{mysql_type_name} ne $SUBS->{type}->($field->{type}) ||
                $db_columns->{$field_name}{NULLABLE} ne $field->{null}) {
                #print "default:'" . $db_columns->{$field_name}{COLUMN_DEF} . "','" . $field->{default} . "'\n";
                #print "auto_increment:'" . $db_columns->{$field_name}{mysql_is_auto_increment} . "','" . isTrue($field->{auto_increment}) . "'\n";
                #print "type:'" . $db_columns->{$field_name}{mysql_type_name} . "','" . $SUBS->{type}->($field->{type}) . "'\n";
                #print "null:'" . $db_columns->{$field_name}{NULLABLE} . "','$field->{null}'\n";

                my $field_sql = $SUBS->{field}->($field_name, $field);
                my $sql = "ALTER TABLE $table_name CHANGE $field_name $field_sql";
                #print "$sql\n";
                $DB->do($sql) || die $DB->errstr;
            }
        } else {
            # add field to DB
            my $field_sql = $SUBS->{field}->($field_name, $field);
            my $sql = "ALTER TABLE $table_name ADD $field_sql";
            #print "$sql\n";
            $DB->do($sql) || die $DB->errstr;
        }
        if ($field->{primary_key}) {
            $indexes->{PRIMARY}->{fields} = "$field_name";
        }
    }
    foreach my $field_name (keys %$db_columns) {
        next if ($fields->{$field_name});
        # delete field from DB
        my $sql = "ALTER TABLE $table_name DROP $field_name";
        #print "$sql\n";
        $DB->do($sql) || die $DB->errstr;
    }

    my $db_indexes = $SUBS->{index}->($DB, $table_name);

    foreach my $index_name (keys %$indexes) {
        my $index = $indexes->{$index_name};
        my $fields = $index->{fields};

       my $create_sql = "CREATE " .  (($index_name eq 'PRIMARY')?"PRIMARY":($index->{unique}?"UNIQUE":"")) . 
                        " INDEX " . (($index_name eq 'PRIMARY')?"":$index_name) . 
                        " ON $table_name($fields)";
       my $drop_sql = "DROP " .  (($index_name eq 'PRIMARY')?"PRIMARY":"") . " INDEX " . (($index_name eq 'PRIMARY')?"":$index_name) .  " ON $table_name";
        if ($db_indexes->{$index_name}) {
           if ($fields ne $db_indexes->{$index_name}->{fields}) {
               #print "$drop_sql\n";
               $DB->do($drop_sql) || die $DB->errstr;
               #print "$create_sql\n";
               $DB->do($create_sql) || die $DB->errstr;
           }
        } else {
            #print "$create_sql\n";
            $DB->do($create_sql) || die $DB->errstr;
        }
    }

    foreach my $index_name (keys %$db_indexes) {
        next if ($indexes->{$index_name});
        my $drop_sql = "DROP " .  (($index_name eq 'PRIMARY')?"PRIMARY":"") . " INDEX " . (($index_name eq 'PRIMARY')?"":$index_name) .  " ON $table_name";
        #print "$drop_sql\n";
        $DB->do($drop_sql) || die $DB->errstr;
    }

    return;
}

=head1 AUTHOR

Patrick Gillan <pgillan@minorimpact.com>

=cut

1;
