use strict;
use warnings;

use Test::More tests => 17;
use Test::Fatal qw( dies_ok exception );

use DBIx::Migration;

eval { require DBD::SQLite };
my $class = $@ ? 'SQLite2' : 'SQLite';

like exception { DBIx::Migration->new( { dsn => "dbi:$class:dbname=./t/missing/sqlite_test" } )->version },
  qr/unable to open database file/, 'missing database file';

my $m = DBIx::Migration->new;
dies_ok { $m->version } '"dsn" not set';
$m->dsn( "dbi:$class:dbname=./t/sqlite_test" );

ok !exists $m->{ _dbh_clone }, '_dbh_clone does not exist';
ok !exists $m->{ dbh },        'dbh does not exist';

is $m->version, undef, '"dbix_migration" table does not exist == migrate() not called yet';

ok exists $m->{ _dbh_clone },       '_dbh_clone exists';
ok !$m->{ _dbh_clone }->{ Active }, 'disconnected';

ok exists $m->{ dbh },  'dbh exists';
ok $m->dbh->{ Active }, 'connected';

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
subtest "migrate to version $target_version" => \&migrate_to_version_assertion, $target_version;

$target_version = 0;
subtest "migrate to version $target_version" => \&migrate_to_version_assertion, $target_version;

my $m1 = DBIx::Migration->new( dbh => $m->dbh );

is $m1->version, 0, '"dbix_migration" table exists and its "version" value is 0';

END {
  unlink './t/sqlite_test';
}
