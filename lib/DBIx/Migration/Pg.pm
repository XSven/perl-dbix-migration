package DBIx::Migration::Pg;

our $VERSION = '0.31';

use Moo;
use MooX::StrictConstructor;

use Log::Any        qw( $Logger );
use Types::Standard qw( Str );

use namespace::clean -except => [ qw( new ) ];

extends 'DBIx::Migration';

has '+do_before' => (
  default => sub {
    my $self = shift;
    return [ [ 'SET search_path TO ?', {}, $self->managed_schema ] ];
  }
);
has '+do_while' => (
  default => sub {
    my $self = shift;
    return [ sprintf( 'LOCK TABLE %s IN EXCLUSIVE MODE', $self->quoted_tracking_table ) ];
  }
);
has '+dsn' => (
  coerce => sub {
    my $dsn = shift;
    return ( ( $dsn =~ m/\Adbi:Pg:\z/i and exists $ENV{ PGSERVICE } ) ? "dbi:Pg:service=$ENV{ PGSERVICE }" : $dsn );
  }
);
has managed_schema  => ( is => 'ro', isa => Str, default => 'public' );
has tracking_schema => ( is => 'ro', isa => Str, default => 'public' );
has '+placeholders' => (
  default => sub {
    my $self = shift;
    return { dbix_migration_managed_schema => $self->{ _dbh }->quote_identifier( $self->managed_schema ) };
  }
);

sub create_tracking_table {
  my $self = shift;

  my $tracking_schema = $self->dbh->quote_identifier( $self->tracking_schema );
  $Logger->debugf( "Create tracking schema '%s'", $tracking_schema );
  $self->dbh->do( "CREATE SCHEMA IF NOT EXISTS $tracking_schema" );
  $self->SUPER::create_tracking_table;
}

sub quoted_tracking_table {
  my $self = shift;

  return $self->dbh->quote_identifier( undef, $self->tracking_schema, $self->tracking_table );
}

1;
