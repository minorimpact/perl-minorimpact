# NAME

MinorImpact::CLI - Command line library

# SYNOPSIS

    use MinorImpact::CLI;

    $MINORIMPACT = new MinorImpact();

    $user = MinorImpact::CLI::login();

# DESCRIPTION

# SUBROUTINES

## passwordPrompt

- passwordPrompt()
- passwordPrompt(\\%params)

Prompt for a password.

### Params

- confirm

    If true, ask for the password twice to verify a match.
      $password = MinorImpact::CLI::passwordPromp({ username => 'foo' });
      # OUTPUT: Enter Password:
      # OUTPUT:          Again:

- username

    A username to supply for the prompt.

        $password = MinorImpact::CLI::passwordPromp({ username => 'foo' });
        # OUTPUT: Enter Password for 'foo':

# AUTHOR

Patrick Gillan <pgillan@gmail.com>
