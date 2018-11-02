# NAME

MinorImpact::Util::DB - MinorImpact database utilities

# SYNOPSIS

# DESCRIPTION

# METHODS

## addTable

- ::addTable($dbh, \\%params)

A table definition to create, or edit if it already exists.

    MinorImpact::Util::DB::addTable($dbh, {
      name => 'test', 
      fields => {
        int_field => { type => 'int' }
      }
    });

### params

- fields => { $name => \\%hash\[, ... \] }

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

    - default => $string

        Set $string to be the default value for the field.

    - null => TRUE/FALSE

        If FALSE, the field will set to not allow NULL values. Default: TRUE

    - primary\_key => TRUE/FALSEa

        Thil field should be set as primary key.

    - type => $string

        Field type.  Required.

- indexes => { $name => \\%hash\[, ...\] }

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

    - fields => $string

        A comma separated list of fields this index should be applied to. Required.

    - unique => TRUE/FALSE

        This is a unique index.

- name

    Table name.  Required.

## \_dbName

- \_dbName($dbh)

Parsed the database name from $dbh->{Name}.

    $db_name = _dbName($dbh);

## \_indexName

- \_indexName($table\_name, $fields);

Returns a string built from the $table\_name and the comma
separate list of $fields being indexed.

    $index_name = _indexName($table_name, $fields);

# AUTHOR

Patrick Gillan <pgillan@minorimpact.com>
