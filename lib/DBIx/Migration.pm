package DBIx::Migration;

our $VERSION = '0.09';

use Moo;
use boolean               qw( false true );
use DBI                   qw();
use File::Spec            qw();
use Path::Tiny            qw( path );
use Try::Tiny             qw( catch try );
use Types::Common::String qw( NonEmptyStr );
use Types::Standard       qw( Bool Str );
use Types::Path::Tiny     qw( Dir );

use namespace::clean;

has debug                       => ( is => 'rw', isa => Bool );
has dir                         => ( is => 'rw', isa => Dir, coerce => true );
has dsn                         => ( is => 'rw', isa => NonEmptyStr );
has [ qw( password username ) ] => ( is => 'rw', isa => Str, default => '' );
has dbh                         => ( is => 'lazy' );

sub _build_dbh {
  my $self = shift;
  return DBI->connect(
    $self->dsn,
    $self->username,
    $self->password,
    {
      RaiseError => true,
      PrintError => false,
      AutoCommit => true
    }
  );
}

sub migrate {
  my ( $self, $wanted ) = @_;
  $self->_connect;
  $wanted = $self->_newest unless defined $wanted;
  my $version = $self->_version;
  if ( defined $version && ( $wanted == $version ) ) {
    print "Database is already at version $wanted\n" if $self->debug;
    return 1;
  }

  unless ( defined $version ) {
    $self->_create_migration_table;
    $version = 0;
  }

  # Up- or downgrade
  my @need;
  my $type = 'down';
  if ( $wanted > $version ) {
    $type = 'up';
    $version += 1;
    @need = $version .. $wanted;
  } else {
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
      my $text = path( $name )->slurp_raw;
      $text =~ s/\s*--.*$//g;
      for my $sql ( split /;/, $text ) {
        next unless $sql =~ /\w/;
        print "$sql\n" if $self->debug;
        $self->{ _dbh_clone }->do( $sql );
        if ( $self->{ _dbh_clone }->err ) {
          die "Database error: " . $self->{ _dbh_clone }->errstr;
        }
      }
      $ver -= 1 if ( ( $ver > 0 ) && ( $type eq 'down' ) );
      $self->_update_migration_table( $ver );
    }
  } else {
    my $newver = $self->_version;
    print "Database is at version $newver, couldn't migrate to $wanted\n"
      if ( $self->debug && ( $wanted != $newver ) );
    return 0;
  }
  $self->_disconnect;
  return 1;
}

sub version {
  my $self = shift;
  $self->_connect;
  my $version = $self->_version;
  $self->_disconnect;
  return $version;
}

sub _connect {
  my $self = shift;
  $self->{ _dbh_clone } = $self->dbh->clone( {} );
  return;
}

sub _create_migration_table {
  my $self = shift;
  $self->{ _dbh_clone }->do( <<"EOF");
CREATE TABLE dbix_migration (
    name VARCHAR(64) PRIMARY KEY,
    value VARCHAR(64)
);
EOF
  $self->{ _dbh_clone }->do( <<"EOF");
    INSERT INTO dbix_migration ( name, value ) VALUES ( 'version', '0' );
EOF
}

sub _disconnect {
  my $self = shift;
  $self->{ _dbh_clone }->disconnect;
  return;
}

sub _files {
  my ( $self, $type, $need ) = @_;
  my @files;
  for my $i ( @$need ) {
    no warnings 'uninitialized';
    opendir( DIR, $self->dir ) or die $!;
    while ( my $file = readdir( DIR ) ) {
      next unless $file =~ /(^|\D)${i}_$type\.sql$/;
      $file = $self->dir->child( $file );
      push @files, { name => $file, version => $i };
    }
    closedir( DIR );
  }
  return undef unless @$need == @files;
  return @files ? \@files : undef;
}

sub _newest {
  my $self   = shift;
  my $newest = 0;

  opendir( DIR, $self->dir ) or die $!;
  while ( my $file = readdir( DIR ) ) {
    next unless $file =~ /_up\.sql$/;
    $file =~ /\D*(\d+)_up.sql$/;
    $newest = $1 if $1 > $newest;
  }
  closedir( DIR );

  return $newest;
}

sub _update_migration_table {
  my ( $self, $version ) = @_;
  $self->{ _dbh_clone }->do( <<"EOF");
UPDATE dbix_migration SET value = '$version' WHERE name = 'version';
EOF
}

sub _version {
  my $self = shift;

  try {
    my $dbh = $self->{ _dbh_clone };
    print "Using database handle $dbh\n" if $self->debug;
    my $sth = $dbh->prepare( <<'EOF');
SELECT value FROM dbix_migration WHERE name = ?;
EOF
    $sth->execute( 'version' );
    my $version;
    # TODO: The loop is strange. There should be only one row!
    for my $val ( $sth->fetchrow_arrayref ) {
      $version = $val->[ 0 ];
    }
    $version;
  } catch {
    # FIXME: make it portable
    # https://www.perlmonks.org/?node=DBI%20Recipes#tablecheck
    # https://www.perlmonks.org/?node_id=500050 (Checking for DB table existence using DBI/DBD)
    # the first match refers to SQLite and the second match refers to PostgreSQL
    # die $_ unless m/no such table: dbix_migration|relation "dbix_migration" does not exist/;
    undef;
  }
}

1;
