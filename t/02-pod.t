use strict;
use warnings;

use Test::More;

BEGIN { plan skip_all => 'Not release testing context' unless $ENV{ RELEASE_TESTING } }

use Test::Needs { 'Test::Pod' => 1.26 };

Test::Pod::all_pod_files_ok();
