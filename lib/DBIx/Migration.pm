package DBIx::Migration;

our $VERSION = '0.09';

use Moo;
use boolean               qw( false true );
use DBI                   qw();
use File::Spec            qw();
use Path::Tiny            qw( path );
use Try::Tiny             qw( try );
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
  $wanted = $self->_newest_version unless defined $wanted;
  my $version = $self->_get_version_from_migration_table;
  unless ( defined $version ) {
    $self->_create_migration_table;
    $version = 0;
  }

  if ( $wanted == $version ) {
    print STDERR "Database is already at version $wanted\n" if $self->debug;
    return true;
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
      print STDERR qq/Processing "$name"\n/ if $self->debug;
      next unless $file;
      my $text = path( $name )->slurp_raw;
      $text =~ s/\s*--.*$//g;
      for my $sql ( split /;/, $text ) {
        next unless $sql =~ /\w/;
        #print STDERR "$sql\n" if $self->debug;
        $self->{ _dbh_clone }->do( $sql );
        if ( $self->{ _dbh_clone }->err ) {
          die "Database error: " . $self->{ _dbh_clone }->errstr;
        }
      }
      $ver -= 1 if ( ( $ver > 0 ) && ( $type eq 'down' ) );
      $self->_update_migration_table( $ver );
    }
  } else {
    my $newver = $self->_get_version_from_migration_table;
    print STDERR "Database is at version $newver, couldn't migrate to $wanted\n"
      if ( $self->debug && ( $wanted != $newver ) );
    return false;
  }
  $self->_disconnect;
  return true;
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
  $self->{ _dbh_clone } = $self->dbh->clone( {} );
  return;
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
    $self->dir->visit(
      sub {
        return unless m/(?:\z|\D)${i}_$type\.sql$/;
        push @files, { name => $_, version => $i };
      }
    );
  }
  return undef unless @$need == @files;
  return @files ? \@files : undef;
}

sub _newest_version {
  my $self = shift;

  my $newest_version = 0;
  $self->dir->visit(
    sub {
      return unless m/_up\.sql\z/;
      m/\D*(\d+)_up.sql\z/;
      $newest_version = $1 if $1 > $newest_version;
    }
  );

  $newest_version;
}

sub _get_version_from_migration_table {
  my $self = shift;

  try {
    my $sth = $self->{ _dbh_clone }->prepare( <<'EOF');
SELECT value FROM dbix_migration WHERE name = ?;
EOF
    $sth->execute( 'version' );
    my $version;
    # TODO: The loop is strange. There should be only one row!
    for my $val ( $sth->fetchrow_arrayref ) {
      $version = $val->[ 0 ];
    }
    $version;
  };
}

sub _create_migration_table {
  my $self = shift;

  $self->{ _dbh_clone }->do( <<'EOF');
CREATE TABLE dbix_migration ( name VARCHAR(64) PRIMARY KEY, value VARCHAR(64) );
EOF
  $self->{ _dbh_clone }->do( <<'EOF', undef, 'version', 0 );
INSERT INTO dbix_migration ( name, value ) VALUES ( ?, ? );
EOF

  undef;
}

sub _update_migration_table {
  my ( $self, $version ) = @_;

  $self->{ _dbh_clone }->do( <<'EOF', undef, $version, 'version' );
UPDATE dbix_migration SET value = ? WHERE name = ?;
EOF

  undef;
}

1;
