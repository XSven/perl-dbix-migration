use strict;
use warnings;

use Test::More import => [ qw( BAIL_OUT use_ok ) ], tests => 2;
use Test::API import => [ qw( class_api_ok ) ];

my $module;

BEGIN {
  $module = 'DBIx::Migration';
  use_ok( $module ) or BAIL_OUT "Cannot load module '$module'!";
}

# "before" should not be part of the API:
# https://github.com/haarg/MooX-SetOnce/issues/2
class_api_ok( $module, qw( before new dir debug dbh dsn username password migrate version ) );
