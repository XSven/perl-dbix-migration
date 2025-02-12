use strict;
use warnings;

use Test::More import => [ qw( BAIL_OUT is ok plan subtest use_ok ) ], tests => 7;
use Test::Output qw( stderr_like stdout_is stdout_like );
use POSIX        qw( EXIT_FAILURE EXIT_SUCCESS );

my $module;

BEGIN {
  $module = 'DBIx::Migration::CLI';
  use_ok( $module ) or BAIL_OUT "Cannot load module '$module'!";
}

ok my $coderef = $module->can( 'run' ), 'has "run" subroutine';
my $got_exitval;

subtest '-V' => sub {
  plan tests => 2;

  stdout_is { $got_exitval = $coderef->( '-V' ) } "Version:\n  0.11\n\n", 'check stdout';
  is $got_exitval, EXIT_SUCCESS, 'check exit value';
};

subtest '-h' => sub {
  plan tests => 2;

  stdout_like { $got_exitval = $coderef->( '-h' ) } qr/\AUsage:.+Options:.+Arguments:.+/s, 'check stdout';
  is $got_exitval, EXIT_SUCCESS, 'check exit value';
};

subtest 'missing mandatory arguments' => sub {
  plan tests => 2;

  stderr_like { $got_exitval = $coderef->() } qr/\AMissing mandatory arguments\nUsage:.+/s, 'check stderr';
  is $got_exitval, 2, 'check exit value';
};

subtest 'unknown option' => sub {
  plan tests => 2;

  stderr_like { $got_exitval = $coderef->( '-g' ) } qr/\AUnknown option: g\nUsage:.+/s, 'check stderr';
  is $got_exitval, 2, 'check exit value';
};

subtest 'missing database file' => sub {
  plan tests => 2;

  stderr_like { $got_exitval = $coderef->( 'dbi:SQLite:dbname=./t/missing/test.db' ) }
  qr/unable to open database file.+\nUsage:.+/s, 'check stderr';
  is $got_exitval, 2, 'check exit value';
};
