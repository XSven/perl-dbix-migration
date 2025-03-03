use strict;
use warnings;

use Text::Table::Tiny qw( generate_table );

my $rows = [
  [ '',                        'DBIx::Migration',                 'App::Sqitch' ],
  [ 'change',                  'migration',                       'change' ],
  [ 'SQL script types',        'up, down',                        'deploy, revert, verify' ],
  [ 'tracking',                'tracking table',                  'registry tables' ],
  [ 'dependency relationship', 'linear (numbered consecutively)', 'tree like (requires)' ]
];

print generate_table( rows => $rows, header_row => 1, indent => 2, top_and_tail => 1 ), "\n"
