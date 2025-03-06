use strict;
use warnings;

use Test::More import => [ qw( BAIL_OUT like use_ok ) ], tests => 7;
use Test::API import => [ qw( class_api_ok ) ];
use Test::Fatal qw( exception );

my ( $class, $subclass );

BEGIN {
  $class = 'DBIx::Migration';
  use_ok( $class ) or BAIL_OUT "Cannot load class '$class'!";
  $subclass = 'DBIx::Migration::Pg';
  use_ok( $subclass ) or BAIL_OUT "Cannot load class '$subclass'!";
}

# "before" should not be part of the API:
# https://github.com/haarg/MooX-SetOnce/issues/2
class_api_ok( $class,
  qw( before new dbh dir dsn username password tracking_table apply_managed_schema quoted_tracking_table driver migrate version ));

class_api_ok( $subclass, qw( new managed_schema tracking_schema apply_managed_schema quoted_tracking_table ) );

like exception { $class->new() }, qr/\Aboth dsn and dbh are not set/, '"dsn" or "dbh" are both absent';

like exception { $class->new( dsn => 'dbi:Mock:', dbh => DBI->connect( 'dbi:Mock:', undef, undef, {} ) ) },
  qr/\Adsn and dbh cannot be used at the same time/, '"dsn" and "dbh" are mutually exclusive';

like exception { $class->new( dbh => DBI->connect( 'dbi:Mock:', undef, undef, {} ), username => 'foo' ) },
  qr/\Adbh and username cannot be used at the same time/, '"dbh" and "username" are mutually exclusive';
