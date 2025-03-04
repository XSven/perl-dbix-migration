use strict;
use warnings;

#https://stackoverflow.com/questions/24547252/podusage-help-formatting/24812485#24812485

package DBIx::Migration::CLI;

our $VERSION = '0.18';

use DBIx::Migration   ();
use Getopt::Std       qw( getopts );
use Log::Any::Adapter ();
use POSIX             qw( EXIT_FAILURE EXIT_SUCCESS );
use Try::Tiny         qw( catch try );

sub run {
  local @ARGV = @_;

  my $opts;
  my $exitval;
  {
    local $SIG{ __WARN__ } = sub {
      my $warning = shift;
      chomp $warning;
      $exitval = _usage( -exitval => 2, -message => $warning );
    };
    getopts( '-Vhp:t:u:v', $opts = {} );
  }
  return $exitval if defined $exitval;

  if ( $opts->{ V } ) {
    return _usage( -flavour => 'version' );
  } elsif ( $opts->{ h } ) {
    return _usage( -flavour => 'long' );
  }

  return _usage( -exitval => 2, -message => 'Missing mandatory arguments' ) unless @ARGV;

  $exitval = try {
    Log::Any::Adapter->set( { category => 'DBIx::Migration' }, 'Stderr' ) if exists $opts->{ v };
    my $dsn = shift @ARGV;
    if ( @ARGV ) {
      my $dir = shift @ARGV;
      my $m   = DBIx::Migration->new(
        dsn      => $dsn,
        dir      => $dir,
        password => $opts->{ p },
        username => $opts->{ u },
        exists $opts->{ t } ? ( tracking_schema => $opts->{ t } ) : ()
      );

      return ( $m->migrate( shift @ARGV ) ? EXIT_SUCCESS : EXIT_FAILURE );
    } else {
      my $m = DBIx::Migration->new(
        dsn      => $dsn,
        password => $opts->{ p },
        username => $opts->{ u },
        exists $opts->{ t } ? ( tracking_schema => $opts->{ t } ) : ()
      );
      my $version = $m->version;
      print STDOUT ( defined $version ? $version : '' ), "\n";
      return EXIT_SUCCESS;
    }
  } catch {
    chomp;
    return _usage( -exitval => 2, -message => $_ );
  };

  return $exitval;
}

sub _usage {
  my %args;
  {
    use warnings FATAL => qw( misc uninitialized );
    %args = ( -exitval => EXIT_SUCCESS, -flavour => 'short', @_ );
  };

  require Pod::Find;
  require Pod::Usage;

  my %sections = ( long => 'SYNOPSIS|OPTIONS|ARGUMENTS', short => 'SYNOPSIS', version => 'VERSION' );
  Pod::Usage::pod2usage(
    -exitval => 'NOEXIT',
    -indent  => 2,
    -input   => Pod::Find::pod_where( { -inc => 1 }, __PACKAGE__ ),
    exists $args{ -message } ? ( -message => $args{ -message } ) : (),
    -output   => ( $args{ -exitval } == EXIT_SUCCESS ) ? \*STDOUT : \*STDERR,
    -sections => $sections{ $args{ -flavour } },
    -verbose  => 99,
    -width    => 120
  );

  return $args{ -exitval };
}

1;
