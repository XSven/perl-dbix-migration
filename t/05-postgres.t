use strict;
use warnings;

use Test::More import => [ qw( is ok plan subtest ) ];
use Test::Fatal qw( dies_ok );

eval { require Test::PostgreSQL };
plan $@ eq '' ? ( tests => 11 ) : ( skip_all => 'Test::PostgresSQL required' );

require DBIx::Migration;

my $pgsql = eval { Test::PostgreSQL->new() } or do {
  no warnings 'once';
  plan skip_all => $Test::PostgreSQL::errstr;
};

my $m = DBIx::Migration->new;
dies_ok { $m->version } '"dsn" not set';
$m->dsn( $pgsql->dsn );
is $m->version, undef, '"dbix_migration" table does not exist == migrate() not called yet';
dies_ok { $m->migrate( 1 ) } '"dir" not set';
$m->dir( './t/sql/' );

sub migrate_to_version_assertion {
  my ( $version ) = @_;
  plan tests => 2;

  ok $m->migrate( $version ), 'migrate';
  is $m->version, $version, 'check version';
}

my $target_version = 1;
subtest "migrate to version $target_version" => \&migrate_to_version_assertion, $target_version;

$target_version = 2;
subtest "migrate to version $target_version" => \&migrate_to_version_assertion, $target_version;

$target_version = 1;
subtest "migrate to version $target_version" => \&migrate_to_version_assertion, $target_version;

$target_version = 0;
subtest "migrate to version $target_version" => \&migrate_to_version_assertion, $target_version;

$target_version = 2;
ok $m->migrate, 'migrate to newest version';
is $m->version, $target_version, 'check version';

$target_version = 0;
subtest "migrate to version $target_version" => \&migrate_to_version_assertion, $target_version;

my $m1 = DBIx::Migration->new( { dbh => $m->dbh } );

is $m1->version, 0, '"dbix_migration" table exists and its "version" value is 0';

END {
  unlink './t/sqlite_test';
}
