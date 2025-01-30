use strict;
use warnings;

use Test::More tests => 18;
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

is $m->version, undef, 'dbix_migration table does not exist == no migration has taken place yet';

ok exists $m->{ _dbh_clone },       '_dbh_clone exists';
ok !$m->{ _dbh_clone }->{ Active }, 'disconnected';

ok exists $m->{ dbh },  'dbh exists';
ok $m->dbh->{ Active }, 'connected';

dies_ok { $m->migrate( 1 ) } '"dir" not set';
$m->dir( './t/sql/' );
$m->migrate( 1 );

isnt $m->{ _dbh }, $m->dbh, 'same object';
is( $m->version, 1 );

$m->migrate( 2 );
is( $m->version, 2 );

$m->migrate( 1 );
is( $m->version, 1 );

$m->migrate( 0 );
is( $m->version, 0 );

$m->migrate( 2 );
is( $m->version, 2 );

$m->migrate( 0 );
is( $m->version, 0 );

my $m2 = DBIx::Migration->new( { dbh => $m->dbh, dir => './t/sql/' } );

is( $m2->version, 0 );

END {
  unlink './t/sqlite_test';
}
