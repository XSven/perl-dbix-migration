use strict;
use warnings;

package DBIx::Migration;

our $VERSION = '0.09';

use parent qw( Class::Accessor::Fast );

use DBI                   qw();
use File::Slurp           qw();
use File::Spec::Functions qw();

__PACKAGE__->mk_accessors( qw( debug dir dsn password username dbh  ) );

sub migrate {
  my ( $self, $wanted ) = @_;

  $self->_connect;

  $wanted = $self->_newest unless defined $wanted;

  my $version = $self->_get_version_from_migration_table;
  $self->_create_migration_table, $version = 0 unless defined $version;

  my @need;
  my $type;
  if ( $wanted == $version ) {
    print qq/Database is already at version $wanted\n/ if $self->debug;
    return 1;
  } elsif ( $wanted > $version ) {    # upgrade
    $type = 'up';
    $version += 1;
    @need = $version .. $wanted;
  } else {                            # downgrade
    $type = 'down';
    $wanted += 1;
    @need = reverse( $wanted .. $version );
  }
  my $files = $self->_files( $type, \@need );
  if ( defined $files ) {
    for my $file ( @$files ) {
      my $name = $file->{ name };
      my $ver  = $file->{ version };
      print qq/Processing "$name"\n/ if $self->debug;
      next unless $file;
      my $text = File::Slurp::read_file( $name );
      $text =~ s/\s*--.*$//g;
      for my $sql ( split /;/, $text ) {
        next unless $sql =~ /\w/;
        print qq/$sql\n/ if $self->debug;
        $self->{ _dbh }->do( $sql );
        if ( $self->{ _dbh }->err ) {
          die sprintf( qq/SQL error when reading file '%s': %s/, $name, $self->{ _dbh }->errstr );
        }
      }
      $ver -= 1 if ( ( $ver > 0 ) && ( $type eq 'down' ) );
      $self->_update_migration_table( $ver );
    }
  } else {
    my $newver = $self->_get_version_from_migration_table;
    print qq/Database is at version $newver, couldn't migrate to version $wanted\n/
      if ( $self->debug && ( $wanted != $newver ) );
    return 0;
  }

  $self->_disconnect;

  return 1;
}

sub version {
  my $self = shift;
  $self->_connect;
  my $version = $self->_get_version_from_migration_table;
  $self->_disconnect;
  return $version;
}

sub _connect {
  my $self = shift;
  return $self->{ _dbh } = $self->dbh->clone( {} ) if $self->dbh;
  $self->{ _dbh } = DBI->connect(
    $self->dsn,
    $self->username,
    $self->password,
    {
      RaiseError => 0,
      PrintError => 0,
      AutoCommit => 1
    }
  ) or die sprintf( qq/Cannot connect to database '%s': %s/, $self->dsn, $DBI::errstr );
  $self->dbh( $self->{ _dbh } );
}

sub _disconnect {
  my $self = shift;
  $self->{ _dbh }->disconnect;
}

sub _files {
  my ( $self, $type, $need ) = @_;

  my @files;
  for my $i ( @$need ) {
    no warnings 'uninitialized';
    opendir( my $dh, $self->dir )
      or die sprintf( qq/Cannot open directory '%s': %s/, $self->dir, $! );
    while ( my $file = readdir( $dh ) ) {
      next unless $file =~ /\D*${i}_$type\.sql\z/;
      $file = File::Spec::Functions::catfile( $self->dir, $file );
      print qq/Found "$file"\n/ if $self->debug;
      push @files, { name => $file, version => $i };
    }
    closedir( $dh );
  }

  return ( @files and @$need == @files ) ? \@files : undef;
}

sub _newest {
  my $self = shift;

  opendir( my $dh, $self->dir )
    or die sprintf( qq/Cannot open directory '%s': %s/, $self->dir, $! );
  my $newest = 0;
  while ( my $file = readdir( $dh ) ) {
    next unless $file =~ /_up\.sql\z/;
    $file =~ /\D*(\d+)_up.sql\z/;
    $newest = $1 if $1 > $newest;
  }
  closedir( $dh );

  return $newest;
}

sub _create_migration_table {
  my $self = shift;

  $self->{ _dbh }->do( <<'EOF');
CREATE TABLE dbix_migration ( name VARCHAR(64) PRIMARY KEY, value VARCHAR(64) );
EOF
  $self->{ _dbh }->do( <<'EOF', undef, 'version', 0 );
INSERT INTO dbix_migration ( name, value ) VALUES ( ?, ? );
EOF
}

sub _update_migration_table {
  my ( $self, $version ) = @_;

  $self->{ _dbh }->do( <<'EOF', undef, $version, 'version' );
UPDATE dbix_migration SET value = ? WHERE name = ?;
EOF
}

sub _get_version_from_migration_table {
  my $self = shift;

  eval {
    my $sth = $self->{ _dbh }->prepare( <<'EOF');
SELECT value FROM dbix_migration WHERE name = ?;
EOF
    $sth->execute( 'version' );
    my $version = undef;
    for my $val ( $sth->fetchrow_arrayref ) {
      $version = $val->[ 0 ];
    }
    $version;
  };
}

1;
