use strict;
use warnings;

use Test::More import => [ qw( is like note ok plan subtest ) ];
use Test::Fatal qw( dies_ok exception );

use Path::Tiny qw( cwd tempdir );

eval { require DBD::SQLite };
plan $@ eq '' ? ( tests => 16 ) : ( skip_all => 'DBD::SQLite required' );

require DBIx::Migration;

like exception { DBIx::Migration->new( { dsn => 'dbi:SQLite:dbname=./t/missing/test.db' } )->version },
  qr/unable to open database file/, 'missing database file';

my $m = DBIx::Migration->new;
dies_ok { $m->version } '"dsn" not set';
my $tempdir = tempdir( CLEANUP => 1 );
$m->dsn( 'dbi:SQLite:dbname=' . $tempdir->child( 'test.db' ) );
note 'dsn: ', $m->dsn;

is $m->version, undef, '"dbix_migration" table does not exist == migrate() not called yet';

ok $m->dbh->{ Active }, 'connected';

ok $m->migrate( 0 ), 'initially (if the "dbix_migration" table does not exist yet) a database is at version 0';

is $m->version, 0, 'privious migrate() has triggered the "dbix_migration" table creation';

dies_ok { $m->migrate( 1 ) } '"dir" not set';
$m->dir( cwd->child( qw( t sql ) ) );

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

my $m1 = DBIx::Migration->new( { dbh => $m->dbh, dir => $m->dir, debug => 1 } );

is $m1->version, 0, '"dbix_migration" table exists and its "version" value is 0';

ok !$m1->migrate( 3 ), 'sql up migration file is missing';
