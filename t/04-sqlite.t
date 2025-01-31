use strict;
use warnings;

use Test::More import => [ qw( is like ok plan subtest ) ];
use Test::Fatal qw( dies_ok exception );

eval { require DBD::SQLite };
plan $@ eq '' ? ( tests => 14 ) : ( skip_all => 'DBD::SQLite required' );

require DBIx::Migration;

like exception { DBIx::Migration->new( { dsn => 'dbi:SQLite:dbname=./t/missing/sqlite_test' } )->version },
  qr/unable to open database file/, 'missing database file';

my $m = DBIx::Migration->new;
dies_ok { $m->version } '"dsn" not set';
$m->dsn( 'dbi:SQLite:dbname=./t/sqlite_test' );

is $m->version, undef, '"dbix_migration" table does not exist == migrate() not called yet';

ok $m->migrate( 0 ), 'initially (if the "dbix_migration" table does not exist yet) a database is at version 0';

is $m->version, 0, 'privious migrate() has triggered the "dbix_migration" table creation';

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
