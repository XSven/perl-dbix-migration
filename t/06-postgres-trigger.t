use strict;
use warnings;

#https://estuary.dev/postgresql-triggers/

use Test::More import => [ qw( is note ok plan subtest ) ];
use Test::Deep qw( cmp_bag );

use DBI                     qw();
use DBI::Const::GetInfoType qw( %GetInfoType );
use File::Spec::Functions   qw( catdir curdir );

eval { require Test::PostgreSQL };
plan skip_all => 'Test::PostgresSQL required' unless $@ eq '';

my $pgsql = eval { Test::PostgreSQL->new() } or do {
  no warnings 'once';
  plan skip_all => $Test::PostgreSQL::errstr;
};
note 'dsn: ', $pgsql->dsn;

plan tests => 3;

require DBIx::Migration;

my $m = DBIx::Migration->new( { dsn => $pgsql->dsn, dir => catdir( curdir, qw( t trigger ) ), debug => 1 } );

sub migrate_to_version_assertion {
  my ( $version ) = @_;
  plan tests => 2;

  ok $m->migrate( $version ), 'migrate';
  is $m->version, $version, 'check version';
}

# https://pgtap.org/documentation.html#tables_are
sub tables_are($$;$) {
  my ( $schema, $expected_tables, $description ) = @_;

  my @got_tables;
  my $dbh = DBI->connect( $pgsql->dsn );
  if ( defined $schema ) {
    my $sth = $dbh->table_info( '%', defined $schema ? $schema : '%', '%', 'TABLE' );
    while ( my $row = $sth->fetchrow_hashref ) {
      push @got_tables, $row->{ TABLE_NAME };
    }
  } else {
    @got_tables = map { s/\A[^.]+\.//; $_ } grep { !/\Ainformation_schema\./ } $dbh->tables( '%', '%', '%', 'TABLE' );
  }
  # https://metacpan.org/pod/Test::Deep#USING-TEST%3A%3ADEEP-WITH-TEST%3A%3ABUILDER
  cmp_bag \@got_tables, $expected_tables, $description ? $description : ();
}

my $target_version = 1;
subtest "migrate to version $target_version" => \&migrate_to_version_assertion, $target_version;

# these are the same assertions that should test tables_are
tables_are 'public', [ qw( dbix_migration products ) ], 'check tables';
tables_are undef,    [ qw( dbix_migration products ) ], 'check tables';
