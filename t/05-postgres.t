use strict;
use warnings;

use Test::More import => [ qw( is ok plan subtest ) ];
use Test::Fatal qw( dies_ok );

use File::Spec::Functions qw( catdir curdir );

eval { require Test::PostgreSQL };
plan skip_all => 'Test::PostgresSQL required' unless $@ eq '';

my $pgsql = eval { Test::PostgreSQL->new() } or do {
  no warnings 'once';
  plan skip_all => $Test::PostgreSQL::errstr;
};

plan tests => 14;

require DBIx::Migration;

my $m = DBIx::Migration->new;
dies_ok { $m->version } '"dsn" not set';
$m->dsn( $pgsql->dsn );
is $m->version, undef, '"dbix_migration" table does not exist == migrate() not called yet';

ok $m->migrate( 0 ), 'initially (if the "dbix_migration" table does not exist yet) a database is at version 0';

is $m->version, 0, 'privious migrate() has triggered the "dbix_migration" table creation';

dies_ok { $m->migrate( 1 ) } '"dir" not set';
$m->dir( catdir( curdir, qw( t sql ) ) );

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

my $m1 = DBIx::Migration->new( { dbh => $m->dbh, dir => $m->dir } );

is $m1->version, 0, '"dbix_migration" table exists and its "version" value is 0';

ok ! $m1->migrate( 3 ), 'sql up migration file is missing';
