use strict;
use warnings;

use Test::More import => [ qw( explain is note ok plan subtest ) ];
use Test::Deep qw( cmp_bag );

use DBI                     qw();
use DBI::Const::GetInfoType qw( %GetInfoType );
use Path::Tiny              qw( cwd );

eval { require Test::PostgreSQL };
plan $@ eq '' ? ( tests => 2 ) : ( skip_all => 'Test::PostgresSQL required' );

require DBIx::Migration;

my $pgsql = eval { Test::PostgreSQL->new() } or do {
  no warnings 'once';
  plan skip_all => $Test::PostgreSQL::errstr;
};
note 'dsn: ', $pgsql->dsn;

my $m = DBIx::Migration->new( dsn => $pgsql->dsn, dir => cwd->child( qw( t trigger ) ), debug => 1 );

sub migrate_to_version_assertion {
  my ( $version ) = @_;
  plan tests => 2;

  ok $m->migrate( $version ), 'migrate';
  is $m->version, $version, 'check version';
}

my $target_version = 1;
subtest "migrate to version $target_version" => \&migrate_to_version_assertion, $target_version;

my $dbh = DBI->connect( $pgsql->dsn );
my $sth = $dbh->table_info( '%', 'public', '%', 'TABLE' );
my @table_names;
while ( my $row = $sth->fetchrow_hashref ) {
  push @table_names, $row->{ TABLE_NAME };
}
cmp_bag \@table_names, [ qw( dbix_migration products ) ], 'check tables';
